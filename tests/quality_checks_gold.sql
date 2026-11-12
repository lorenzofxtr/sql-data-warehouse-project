-- Purpose: Data quality checks for the gold layer. Run after creating the gold views.
-- WARNING: Read-only. Changes nothing.

USE DataWarehouse;
GO

-- ============================================================
-- dim_customers
-- ============================================================

-- Check that the surrogate key is unique
-- Expectation: No result
SELECT customer_key, COUNT(*) AS number
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Check that joining the ERP tables did not duplicate any customer
-- Expectation: No result
SELECT customer_id, COUNT(*) AS number
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check the gender after combining CRM and ERP
-- Expectation: only Male, Female and N/A
SELECT DISTINCT gender
FROM gold.dim_customers;

-- ============================================================
-- dim_products
-- ============================================================

-- Check that the surrogate key is unique
-- Expectation: No result
SELECT product_key, COUNT(*) AS number
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Check that only the current version of each product was kept
-- Expectation: No result
SELECT product_number, COUNT(*) AS number
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- Check for products without a category
-- Expectation: only the known source issue (7 pedal products, category_id 'CO_PE'; see the README)
SELECT product_number, product_name, category_id
FROM gold.dim_products
WHERE category IS NULL;

-- ============================================================
-- fact_sales
-- ============================================================

-- Check that the joins with the dimensions did not add or remove sales
-- Expectation: the two numbers are the same
SELECT
	(SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_rows,
	(SELECT COUNT(*) FROM gold.fact_sales) AS gold_rows;

-- Check that every sale found its customer and its product
-- Expectation: No result
SELECT *
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
	ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products AS p
	ON p.product_key = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;
