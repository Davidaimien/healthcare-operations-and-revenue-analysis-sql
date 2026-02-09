/********************************************************
  HEALTHCARE ANALYTICS: BUSINESS INSIGHT QUERIES
  This script answers four key business questions related to:
  - Department operational efficiency
  - Patient retention and repeat visit behavior
  - Revenue trends by insurance provider
  - Revenue loss due to appointment no-shows
*********************************************************/


-- QUESTION 1: Which department has the highest volume of appointments
-- but the lowest average billing?

WITH dept_metrics AS (
    SELECT
    	dept_name
    	,COUNT(DISTINCT appointments.appointment_id) AS total_appt
    	,AVG(billing.amount) AS avg_billing
    FROM departments
    	INNER JOIN doctors
    		ON doctors.dept_id = departments.dept_id
    	INNER JOIN appointments
    		ON appointments.doctor_id = doctors.doctor_id
    	INNER JOIN treatments
    		ON treatments.appointment_id = appointments.appointment_id
    	INNER JOIN billing
    		ON billing.treatment_id = treatments.treatment_id
    GROUP BY
        departments.dept_id
	    ,dept_name)
    SELECT
        dept_name
        ,total_appt
        ,CAST(avg_billing AS DECIMAL(10,2)) AS avg_billing
    FROM dept_metrics
    ORDER BY
        total_appt DESC
        ,avg_billing ASC


-- QUESTION 2:Which doctors have the highest rate of repeat patients
-- compared to one-time visitors?

WITH patient_visit_counts AS (
    SELECT
        doctor_id
        ,patient_id
        ,COUNT(*) AS appt_count
    FROM appointments
    GROUP BY doctor_id, patient_id)
    ,patient_metrics AS (
        SELECT
            doctor_id
            ,COUNT(patient_id) AS total_unique_patients
            ,SUM(CASE WHEN appt_count > 1 THEN 1 ELSE 0 END) AS repeat_patient_count
            ,SUM(CASE WHEN appt_count = 1 THEN 1 ELSE 0 END) AS one_time_visitor_count
        FROM patient_visit_counts
        GROUP BY doctor_id)
    SELECT
        CONCAT(doctors.first_name, ' ', doctors.last_name) AS doc_fullname
        ,patient_metrics.total_unique_patients
        ,patient_metrics.one_time_visitor_count
        ,patient_metrics.repeat_patient_count
        ,FORMAT(CAST(patient_metrics.repeat_patient_count AS FLOAT) / NULLIF(patient_metrics.total_unique_patients, 0), 'p') AS repeat_rate
    FROM doctors
        JOIN patient_metrics
            ON doctors.doctor_id = patient_metrics.doctor_id
    ORDER BY 
        CAST(patient_metrics.repeat_patient_count AS FLOAT) / NULLIF(patient_metrics.total_unique_patients, 0) DESC


--QUESTION 3: What is the total revenue generated per month, broken down by insurance provider?
--NOTE: Revenue includes only completed appointments with successful billing.

SELECT 
    insurance_provider.provider_name AS insurance_provider
    ,FORMAT(DATEFROMPARTS(YEAR(billing.bill_date), MONTH(billing.bill_date), 1), 'MMM-yyyy') AS bill_month
    ,SUM(billing.amount) AS monthly_revenue
FROM insurance_provider
    INNER JOIN patients 
        ON patients.provider_id = insurance_provider.provider_id
    INNER JOIN appointments 
        ON appointments.patient_id = patients.patient_id
    INNER JOIN treatments 
        ON treatments.appointment_id = appointments.appointment_id
    INNER JOIN billing
        ON billing.treatment_id = treatments.treatment_id
WHERE 
    appointments.status = 'Completed'
    AND billing.payment_status = 'Paid'
GROUP BY 
    insurance_provider.provider_id
    ,insurance_provider.provider_name
    ,DATEFROMPARTS(YEAR(billing.bill_date), MONTH(billing.bill_date), 1)
ORDER BY 
    DATEFROMPARTS(YEAR(billing.bill_date), MONTH(billing.bill_date), 1) ASC


--QUESTION 4. Identify the top 3 departments with the highest no-show rate
-- and calculate the estimated lost revenue based on their average billing per appointment

WITH appt_stats AS (
    SELECT
        departments.dept_id
        ,departments.dept_name
        ,COUNT(appointments.appointment_id) AS total_appt
        ,SUM(CASE WHEN appointments.status = 'No-show' THEN 1 ELSE 0 END) AS no_show_count
    FROM departments
            INNER JOIN doctors
                ON doctors.dept_id = departments.dept_id
            INNER JOIN appointments 
                ON appointments.doctor_id = doctors.doctor_id
    WHERE appointments.[status] IN ('Completed', 'No-show') 
    GROUP BY 
        departments.dept_id
        ,departments.dept_name)
    
    ,billing_stats AS (
        SELECT
            doctors.dept_id
            ,AVG(billing.amount) AS avg_bill_per_appt
        FROM doctors
            INNER JOIN appointments 
                ON appointments.doctor_id = doctors.doctor_id
            INNER JOIN treatments 
                ON treatments.appointment_id = appointments.appointment_id
            INNER JOIN billing
                ON billing.treatment_id = treatments.treatment_id
        WHERE appointments.[status] = 'Completed'
            AND billing.payment_status = 'Paid'
        GROUP BY doctors.dept_id)
    
    SELECT TOP 3
        appt_stats.dept_name
        ,FORMAT(appt_stats.no_show_count * 1.0 / NULLIF(appt_stats.total_appt, 0), 'P') AS no_show_rate
        ,CAST(appt_stats.no_show_count * billing_stats.avg_bill_per_appt AS DECIMAL(12,2)) AS estimated_lost_revenue
    FROM appt_stats
        INNER JOIN billing_stats
            ON billing_stats.dept_id = appt_stats.dept_id
    ORDER BY appt_stats.no_show_count * 1.0 / NULLIF(appt_stats.total_appt, 0) DESC