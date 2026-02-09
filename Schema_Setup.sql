/*******************************************************************************
1. DATABASE INITIALIZATION & DATA TYPE STANDARDIZATION

Goal: Ensure all columns have appropriate data types for storage efficiency 
      and to prevent data entry errors (e.g., setting IDs to NOT NULL).
*******************************************************************************/

CREATE DATABASE HospitalManagement
GO
USE HospitalManagement
GO
-- Standardizing appointment times to 5-character format (HH:MM)
UPDATE appointments SET appointment_time = LEFT(appointment_time, 5)

-- Modifying columns to enforce data integrity and proper types
ALTER TABLE appointments ALTER COLUMN appointment_id VARCHAR(50) NOT NULL
ALTER TABLE appointments ALTER COLUMN appointment_date DATE NOT NULL
ALTER TABLE appointments ALTER COLUMN patient_id VARCHAR(50)			NOT NULL
ALTER TABLE appointments ALTER COLUMN doctor_id VARCHAR(50)				NOT NULL
ALTER TABLE appointments ALTER COLUMN appointment_date DATE				NOT NULL
ALTER TABLE appointments ALTER COLUMN appointment_time VARCHAR(5)		NOT NULL
ALTER TABLE appointments ALTER COLUMN reason_for_visit VARCHAR(255)		NULL
ALTER TABLE appointments ALTER COLUMN [status] VARCHAR(50)				NOT NULL

ALTER TABLE billing ALTER COLUMN bill_id VARCHAR(50)			NOT NULL
ALTER TABLE billing ALTER COLUMN patient_id VARCHAR(50)			NOT NULL
ALTER TABLE billing ALTER COLUMN treatment_id VARCHAR(50)		NOT NULL
ALTER TABLE billing ALTER COLUMN bill_date DATE					NOT NULL
ALTER TABLE billing ALTER COLUMN amount DECIMAL(10,2)			NULL
ALTER TABLE billing ALTER COLUMN payment_method VARCHAR(50)		NULL
ALTER TABLE billing ALTER COLUMN payment_status VARCHAR(50)		NOT NULL
                   
ALTER TABLE doctors ALTER COLUMN doctor_id VARCHAR(50)			NOT NULL
ALTER TABLE doctors ALTER COLUMN first_name VARCHAR(50)			NOT NULL
ALTER TABLE doctors ALTER COLUMN last_name VARCHAR(50)			NOT NULL
ALTER TABLE doctors ALTER COLUMN specialization VARCHAR(100)	NOT NULL
ALTER TABLE doctors ALTER COLUMN phone_number BIGINT			NULL
ALTER TABLE doctors ALTER COLUMN phone_number VARCHAR(50)		NULL
ALTER TABLE doctors ALTER COLUMN years_experience TINYINT		NULL
ALTER TABLE doctors ALTER COLUMN hospital_branch VARCHAR(100)	NOT NULL
ALTER TABLE doctors ALTER COLUMN email VARCHAR(255)				NULL
                    
ALTER TABLE patients ALTER COLUMN patient_id VARCHAR(50)			NOT NULL
ALTER TABLE patients ALTER COLUMN first_name VARCHAR(50)			NOT NULL
ALTER TABLE patients ALTER COLUMN last_name VARCHAR(50)				NOT NULL
ALTER TABLE patients ALTER COLUMN gender VARCHAR(20)				NULL
ALTER TABLE patients ALTER COLUMN date_of_birth DATE				NOT NULL
ALTER TABLE patients ALTER COLUMN contact_number BIGINT				NULL
ALTER TABLE patients ALTER COLUMN contact_number VARCHAR(100)		NULL
ALTER TABLE patients ALTER COLUMN [address] VARCHAR(255)			NULL
ALTER TABLE patients ALTER COLUMN registration_date DATE			NOT NULL
ALTER TABLE patients ALTER COLUMN insurance_provider VARCHAR(100)	NULL
ALTER TABLE patients ALTER COLUMN insurance_number VARCHAR(100)		NULL
ALTER TABLE patients ALTER COLUMN email VARCHAR(255)				NULL

ALTER TABLE treatments ALTER COLUMN treatment_id VARCHAR(50)	NOT NULL
ALTER TABLE treatments ALTER COLUMN appointment_id VARCHAR(50)	NOT NULL
ALTER TABLE treatments ALTER COLUMN treatment_type VARCHAR(50)	NOT NULL
ALTER TABLE treatments ALTER COLUMN [description] VARCHAR(255)	NULL
ALTER TABLE treatments ALTER COLUMN cost DECIMAL(10,2)			NOT NULL
ALTER TABLE treatments ALTER COLUMN treatment_date DATE			NOT NULL

/*******************************************************************************
2. SCHEMA NORMALIZATION (Implementing 3rd Normal Form)
Goal: Reduce data redundancy by extracting repeating attributes (Departments 
      and Insurance Providers) into specialized lookup tables.
*******************************************************************************/

-- Creating Departments table and linking it to Doctors
CREATE TABLE departments(
    dept_id TINYINT PRIMARY KEY IDENTITY(1,1)
    ,dept_name VARCHAR(100) NOT NULL)

INSERT INTO departments 
    (dept_name) 
VALUES 
    ('Women & Children’s Health')
    ,('Cancer Center')
    ,('Medical Specialties')

ALTER TABLE doctors ADD dept_id TINYINT

-- Mapping doctors to departments based on specialization
UPDATE doctors SET dept_id = 1 WHERE specialization = 'Pediatrics'
UPDATE doctors SET dept_id = 2 WHERE specialization = 'Oncology'
UPDATE doctors SET dept_id = 3 WHERE specialization = 'Dermatology'

-- Normalizing Insurance Providers from the Patients table
CREATE TABLE insurance_provider (
    provider_id TINYINT PRIMARY KEY IDENTITY(1,1)
    ,provider_name VARCHAR(100) UNIQUE NOT NULL)

INSERT INTO insurance_provider 
    (provider_name)
SELECT DISTINCT insurance_provider FROM patients WHERE insurance_provider IS NOT NULL

ALTER TABLE patients ADD provider_id TINYINT

UPDATE patients
SET patients.provider_id = insurance_provider.provider_id
FROM patients
    INNER JOIN insurance_provider 
        ON patients.insurance_provider = insurance_provider.provider_name

-- Dropping the redundant text column now that the ID link is established
ALTER TABLE patients DROP COLUMN insurance_provider

/*******************************************************************************
3. PRIMARY AND FOREIGN KEY CONSTRAINTS
Goal: Establishing Referential Integrity to ensure that the relationships 
      between tables stay consistent.
*******************************************************************************/

-- Adding Primary Keys and Default Values
ALTER TABLE appointments ADD 
    CONSTRAINT PK_appointment_id PRIMARY KEY (appointment_id)
    ,CONSTRAINT df_appointments_status DEFAULT 'Scheduled' FOR [status]

ALTER TABLE billing add 
    CONSTRAINT PK_bill_id PRIMARY KEY (bill_id)
	,CONSTRAINT df_billing_payment_status default 'Unpaid' FOR payment_status
	,CONSTRAINT df_billing_amount DEFAULT 0 FOR amount

ALTER TABLE doctors ADD CONSTRAINT PK_doctor_id PRIMARY KEY (doctor_id)
ALTER TABLE patients ADD CONSTRAINT PK_patient_id PRIMARY KEY (patient_id)

ALTER TABLE treatments ADD 
    CONSTRAINT PK_treatment_id PRIMARY KEY (treatment_id)
    ,CONSTRAINT df_treatments_cost DEFAULT 0 FOR cost

-- Establishing Foreign Key Relationships
ALTER TABLE appointments ADD
    CONSTRAINT FK_appointments_patients FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
	,CONSTRAINT FK_appointments_doctors FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)

ALTER TABLE billing ADD
	CONSTRAINT FK_billing_treatments FOREIGN KEY (treatment_id) REFERENCES treatments(treatment_id)

ALTER TABLE treatments ADD
	CONSTRAINT FK_treatments_appointments FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)

ALTER TABLE doctors ADD
	CONSTRAINT FK_doctors_departments FOREIGN KEY (dept_id) REFERENCES departments(dept_id)

ALTER TABLE patients ADD
	CONSTRAINT FK_patients_insuranceProvider FOREIGN KEY (provider_id) REFERENCES insurance_provider(provider_id)


/*******************************************************************************
4. DATA QUALITY ASSURANCE (QA)
Goal: Verify that the normalization and constraint implementation 
      did not result in data loss or orphaned records.
*******************************************************************************/

-- Checking for 'Orphan' Billing Records
-- Ensures every bill is correctly mapped to a valid treatment.
SELECT 
    bill_id, treatment_id, bill_date, amount
FROM billing
WHERE NOT EXISTS (
    SELECT 1 FROM treatments 
    WHERE treatments.treatment_id = billing.treatment_id)

/*******************************************************************************
5. FINAL CLEANUP
Goal: Removing redundant columns that exist elsewhere in the relational chain.
*******************************************************************************/

-- PRE-DELETION AUDIT
-- Checking if 'patient_id' in the billing table has any active foreign Key dependencies before removal.
SELECT 
    fk.name AS fk_name
FROM sys.foreign_keys fk
WHERE fk.parent_object_id = OBJECT_ID('billing')

/*Once confirmed that billing.patient_id is redundant (since we can reach patient data 
via treatments -> appointments), the column is dropped.*/
ALTER TABLE billing DROP COLUMN patient_id;