-- Purpose: Creates the gold layer views (business-ready data) on top of the silver tables.
-- WARNING: Replaces the gold views if they already exist. No data is deleted (views store no data).

USE DataWarehouse;
GO

-- ============================================================
-- dim_customers
-- ============================================================
-- One row per customer: CRM customer info + ERP birthdate, gender and country.
CREATE OR ALTER VIEW gold.dim_customers AS 
SELECT 
-- Surrogate key generated in the warehouse (does not come from the sources)
ROW_NUMBER() OVER(ORDER BY cst_id) AS customer_key,
ci.cst_id AS customer_id,
ci.cst_key AS customer_number,
ci.cst_firstname AS first_name,
ci.cst_lastname AS last_name,
la.cntry as country,
ci.cst_marital_status AS marital_status,
-- CRM is the master for gender; ERP is used only when CRM has no value
CASE WHEN ci.cst_gndr != 'N/A' THEN ci.cst_gndr
	 ELSE COALESCE(ca.gen, 'N/A')
END AS gender,
ca.bdate AS birthdate,
ci.cst_create_date AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
ON		  ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON		  ci.cst_key = la.cid;
GO

-- ============================================================
-- dim_products
-- ============================================================
-- One row per product (current version only): CRM product info + ERP category info.
-- Known source issue: the 7 products with category 'CO_PE' have no match in erp_px_cat_g1v2,
-- so their category, subcategory and maintenance are NULL (see proc_load_silver.sql).
CREATE OR ALTER VIEW gold.dim_products AS 
SELECT
	-- Surrogate key generated in the warehouse (does not come from the sources)
	ROW_NUMBER () OVER (ORDER BY prd_start_dt, prd_key) AS product_key,
	prd_id AS product_id,
	prd_key AS product_number,
	prd_nm AS product_name,
	cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	prd_cost AS cost,
	prd_line AS product_line,
	prd_start_dt AS start_date 
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON		  pn.cat_id = pc.id
-- Keep only the current version of each product (history is filtered out)
WHERE prd_end_dt IS NULL;
GO

-- ============================================================
-- fact_sales
-- ============================================================
-- One row per sales order line. Source ids are replaced by the surrogate keys of the dimensions.
CREATE OR ALTER VIEW gold.fact_sales AS 
SELECT 
sls_ord_num AS order_number,
-- Keys that connect each sale to gold.dim_products and gold.dim_customers
pr.product_key,
cu.customer_key,
sls_order_dt AS order_date,
sls_ship_dt AS shipping_date,
sls_due_dt AS due_date,
sls_sales AS sales_amount,
sls_quantity AS quantity,
sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON		  sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON		  sd.sls_cust_id = cu.customer_id;
GO
