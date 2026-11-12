-- Purpose: Cleans bronze tables and loads them into silver (all 6 tables: crm_cust_info, crm_prd_info, crm_sales_details, erp_cust_az12, erp_loc_a101, erp_px_cat_g1v2).
-- Full load: each table is emptied (TRUNCATE) before the INSERT, so running it again gives the same result.
-- WARNING: Deletes all current data in these silver tables before reloading them from bronze.
-- Usage: EXEC silver.load_silver;

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

SET STATISTICS TIME ON;

BEGIN TRY
	-- ============================================================
	-- crm_cust_info
	-- ============================================================
	PRINT 'crm_cust_info';
	TRUNCATE TABLE silver.crm_cust_info;
	INSERT INTO silver.crm_cust_info (
				cst_id,
				cst_key,
				cst_firstname,
				cst_lastname,
				cst_marital_status,
				cst_gndr,
				cst_create_date)

	SELECT cst_id
		  ,cst_key
		  -- Source has leading/trailing spaces in names
		  ,TRIM(cst_firstname) AS cst_firstname
		  ,TRIM(cst_lastname) AS cst_lastname
		  -- Map codes to readable values; anything unknown becomes 'N/A'
		  ,CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				ELSE 'N/A'
				END AS cst_marital_status
		  ,CASE WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				ELSE 'N/A'
		   END AS cst_gndr
		  ,cst_create_date
	FROM (
		-- Keep only the most recent record per customer; rows without an id are dropped
		SELECT *,
			ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS last_flag
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
	)t
	WHERE last_flag = 1;

	-- ============================================================
	-- crm_prd_info
	-- ============================================================
	PRINT 'crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
	INSERT INTO silver.crm_prd_info (
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt)
	SELECT
		prd_id,
		-- First 5 characters are the category; '-' becomes '_' to match erp_px_cat_g1v2.id
		REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
		-- The rest is the product key used in crm_sales_details
		SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
		prd_nm,
		-- Missing cost means no cost
		ISNULL(prd_cost, 0) AS prd_cost,
		-- Map codes to readable values; anything unknown becomes 'N/A'
		CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
		WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
		WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
		WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
		ELSE 'N/A'
		END AS prd_line,
		prd_start_dt,
		-- Source end dates are wrong: end = day before the next version starts (NULL = current version)
		DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt
	FROM DataWarehouse.bronze.crm_prd_info;

	-- ============================================================
	-- crm_sales_details
	-- ============================================================
	PRINT 'crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;
	INSERT INTO silver.crm_sales_details (
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price)
	SELECT
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		-- Dates come as INT (e.g. 20101229): INT -> VARCHAR -> DATE; 0 or wrong length becomes NULL
		CASE
			WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END AS sls_order_dt,
		CASE 
			WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
		END AS sls_ship_dt,
		CASE 
			WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
		END AS sls_due_dt,
		-- Business rule: sales = quantity * price. Missing, zero, negative or wrong sales is recalculated
		CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
			ELSE sls_sales
		END AS sls_sales,
		sls_quantity,
		-- Missing, zero or negative price = sales / quantity (NULLIF avoids division by zero)
		CASE WHEN sls_price IS NULL OR sls_price <= 0
			THEN sls_sales / NULLIF(sls_quantity, 0)
			ELSE sls_price
		END AS sls_price
	FROM DataWarehouse.bronze.crm_sales_details;

	-- ============================================================
	-- erp_cust_az12
	-- ============================================================
	PRINT 'erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;
	INSERT INTO silver.erp_cust_az12 (
		cid,
		bdate,
		gen)
	SELECT
		-- Some ids have a 'NAS' prefix; removing it makes them match crm_cust_info.cst_key
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
			ELSE cid
		END AS cid,
		-- Birth dates in the future are invalid
		CASE WHEN bdate > GETDATE() THEN NULL
			ELSE bdate
		END AS bdate,
		-- Normalize case/spaces, map codes and words to readable values; anything else becomes 'N/A'
		CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
			ELSE 'N/A'
		END AS gen
	FROM DataWarehouse.bronze.erp_cust_az12;

	-- ============================================================
	-- erp_loc_a101
	-- ============================================================
	PRINT 'erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	INSERT INTO silver.erp_loc_a101 (
		cid,
		cntry)
	SELECT
		-- Ids come as 'AW-00011000'; removing the hyphen makes them match crm_cust_info.cst_key
		REPLACE(cid, '-', '') AS cid,
		-- Open list: fix only known variations, blank/NULL becomes 'N/A', any other country is kept as it is
		CASE WHEN UPPER(TRIM(cntry)) IN ('USA', 'US', 'UNITED STATES') THEN 'United States'
			WHEN UPPER(TRIM(cntry)) IN ('DE', 'GER', 'GERMANY') THEN 'Germany'
			WHEN UPPER(TRIM(cntry)) IN ('AUS', 'AUSTRALIA') THEN 'Australia'
			WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
			ELSE TRIM(cntry)
		END AS cntry
	FROM DataWarehouse.bronze.erp_loc_a101;

	-- ============================================================
	-- erp_px_cat_g1v2
	-- ============================================================
	-- Source is already clean (no extra spaces, NULLs, blanks or duplicate ids): loaded as it is.
	-- Known source issue, kept as it came: category 'CO_PE' (7 pedal products in crm_prd_info) has no match here,
	-- and 'CO_PD' (Components / Pedals) here has no products. Probably the same category typed two ways;
	-- not changed because the correct code could not be confirmed with the source owner.
	PRINT 'erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	INSERT INTO silver.erp_px_cat_g1v2 (
		id,
		cat,
		subcat,
		maintenance)
	SELECT
		id,
		cat,
		subcat,
		maintenance
	FROM DataWarehouse.bronze.erp_px_cat_g1v2;
END TRY
BEGIN CATCH
PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH

END
GO
