-- Purpose: Creates the procedure that loads the 6 CRM and ERP CSV files into the bronze tables.
-- Full load: each table is emptied (TRUNCATE) and then filled again from its file (BULK INSERT).
-- WARNING: Empties every bronze table before loading. All current bronze data is replaced.
-- Before running: change the folder in the six FROM lines to where this repository is on your machine.
-- Usage: EXEC bronze.load_bronze;

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

-- Shows how long each load takes (Messages tab)
SET STATISTICS TIME ON;

-- If any load fails, the CATCH block at the end prints the error message
BEGIN TRY

    -- ---------- CRM ----------
    -- FIRSTROW = 2 skips the header line; FIELDTERMINATOR = ',' because the files are comma separated;
    -- TABLOCK locks the whole table during the load, which makes it faster.
    -- Known issue: the last line of cust_info.csv is not loaded (the file has no final line break).
    -- That line has no customer id, so nothing is lost. See the README.
    PRINT 'crm_cust_info'
    TRUNCATE TABLE bronze.crm_cust_info;
    BULK INSERT bronze.crm_cust_info
    FROM 'C:\Users\loren\Documents\SQL Pratica\southline-dwh\datasets\source_crm\cust_info.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'crm_prd_info'
    TRUNCATE TABLE bronze.crm_prd_info;
    BULK INSERT bronze.crm_prd_info
    FROM 'C:\Users\loren\Documents\SQL Pratica\southline-dwh\datasets\source_crm\prd_info.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'crm_sales_details'
    TRUNCATE TABLE bronze.crm_sales_details;
    BULK INSERT bronze.crm_sales_details
    FROM 'C:\Users\loren\Documents\SQL Pratica\southline-dwh\datasets\source_crm\sales_details.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );

    -- ---------- ERP ----------
    -- Known issue: the last line of CUST_AZ12.csv is not loaded either (same cause).
    -- It is a real customer (AW00029483), who ends up with no birthdate. See the README.
    PRINT 'erp_cust_az12'
    TRUNCATE TABLE bronze.erp_cust_az12;
    BULK INSERT bronze.erp_cust_az12
    FROM 'C:\Users\loren\Documents\SQL Pratica\southline-dwh\datasets\source_erp\CUST_AZ12.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'erp_loc_a101'
    TRUNCATE TABLE bronze.erp_loc_a101;
    BULK INSERT bronze.erp_loc_a101
    FROM 'C:\Users\loren\Documents\SQL Pratica\southline-dwh\datasets\source_erp\LOC_A101.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
    PRINT 'erp_px_cat_g1v2'
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;
    BULK INSERT bronze.erp_px_cat_g1v2
    FROM 'C:\Users\loren\Documents\SQL Pratica\southline-dwh\datasets\source_erp\PX_CAT_G1V2.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
END TRY
BEGIN CATCH
PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH

END
GO
