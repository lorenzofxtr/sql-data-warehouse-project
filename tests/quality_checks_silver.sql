-- Purpose: Data quality checks for the silver layer. Run on bronze to find issues, then on silver to confirm they are fixed.
-- WARNING: Read-only. Changes nothing.

USE DataWarehouse;
GO

-- ============================================================
-- crm_cust_info
-- ============================================================

-- Check for NULLS or DUPLICATES in the Primary Key
-- Expectation: No Result

SELECT
	cst_id,
	COUNT(*) AS number
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL

-- Check for Unwanted Spaces
-- Expectation: No Result
SELECT cst_firstname, cst_lastname
FROM silver.crm_cust_info
WHERE	cst_firstname != TRIM(cst_firstname)
	OR	cst_lastname != TRIM(cst_lastname)

-- Check Data Standardization and Consistency
-- Expectation: only readable values (e.g. Male, Female, N/A), no abbreviations
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

-- ============================================================
-- crm_prd_info
-- ============================================================

-- Check for Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT prd_id,
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL

-- Check for Unwanted Spaces
-- Expectation: No result
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- Check for NULLS or Negative Numbers
-- Expectation: No result
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

-- Check for Data Standardization & Consistency
-- Expectation: only readable values (Mountain, Road, Other Sales, Touring, N/A)
SELECT DISTINCT prd_line
FROM silver.crm_prd_info

-- Check for invalid date orders
-- Expectation: No result
SELECT * FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt

-- ============================================================
-- crm_sales_details
-- ============================================================

-- Check for invalid dates (bronze only: dates are INT there; in silver they are already DATE)
-- Expectation: shows the dates that become NULL in silver
SELECT sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) != 8

-- Check for invalid date orders
-- Expectation: No result
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

-- Check data consistency between sales, quantity and price
-- Sales must be = Quantity * Price; values must not be NULL, zero or negative
-- Expectation: No result
SELECT DISTINCT
	sls_sales,
	sls_quantity,
	sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

-- ============================================================
-- erp_cust_az12
-- ============================================================

-- Check that every customer id exists in crm_cust_info
-- Expectation: No result
SELECT cid
FROM silver.erp_cust_az12
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info)

-- Check for birth dates in the future
-- Expectation: No result
SELECT bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE()

-- Check Data Standardization and Consistency
-- Expectation: only readable values (Male, Female, N/A)
SELECT DISTINCT gen
FROM silver.erp_cust_az12

-- ============================================================
-- erp_loc_a101
-- ============================================================

-- Check that every customer id exists in crm_cust_info
-- Expectation: No result
SELECT cid
FROM silver.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info)

-- Check Data Standardization and Consistency
-- Expectation: only full country names and N/A
SELECT DISTINCT cntry
FROM silver.erp_loc_a101
ORDER BY cntry

-- ============================================================
-- erp_px_cat_g1v2
-- ============================================================

-- Check the link with crm_prd_info in both directions
-- Expectation: only the known source issue (CO_PD here, CO_PE in crm_prd_info; see proc_load_silver.sql)
SELECT id
FROM silver.erp_px_cat_g1v2
WHERE id NOT IN (SELECT cat_id FROM silver.crm_prd_info)

SELECT DISTINCT cat_id
FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2)

-- Check for Unwanted Spaces
-- Expectation: No result
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE id != TRIM(id)
	OR cat != TRIM(cat)
	OR subcat != TRIM(subcat)
	OR maintenance != TRIM(maintenance)

-- Check for NULLs or blanks (the spaces check above does not catch them)
-- Expectation: No result
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE id IS NULL OR TRIM(id) = ''
	OR cat IS NULL OR TRIM(cat) = ''
	OR subcat IS NULL OR TRIM(subcat) = ''
	OR maintenance IS NULL OR TRIM(maintenance) = ''

-- Check for Duplicates in the Primary Key
-- Expectation: No result
SELECT id, COUNT(*)
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1

-- Check Data Standardization and Consistency
-- Expectation: only readable values, no abbreviations or variations
SELECT DISTINCT cat FROM silver.erp_px_cat_g1v2
SELECT DISTINCT subcat FROM silver.erp_px_cat_g1v2
SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2
