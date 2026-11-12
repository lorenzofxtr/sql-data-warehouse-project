# Data Catalog: Gold Layer

The gold layer is the business-ready part of the warehouse. It is a star schema with two dimensions and one fact, built as views on top of the cleaned silver tables. Use these three views for reports and analysis; the bronze and silver layers are internal.

| View | Type | One row is | Rows |
|---|---|---|---|
| `gold.dim_customers` | Dimension | one customer | 18,484 |
| `gold.dim_products` | Dimension | one product (current version) | 295 |
| `gold.fact_sales` | Fact | one line of a sales order | 60,398 |

The script that creates them is [`scripts/gold/ddl_gold.sql`](../scripts/gold/ddl_gold.sql).

## How the views connect

```
gold.dim_customers.customer_key  1 ──── N  gold.fact_sales.customer_key
gold.dim_products.product_key    1 ──── N  gold.fact_sales.product_key
```

Every sale has a customer and a product: no row in `fact_sales` has an empty key.

```sql
SELECT
    c.country,
    p.category,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products  AS p ON p.product_key  = f.product_key
GROUP BY c.country, p.category;
```

---

## gold.dim_customers

**Purpose:** who the customers are. Combines the CRM customer record with the birthdate, gender and country kept in the ERP.

| Column | Type | Description | Example |
|---|---|---|---|
| `customer_key` | BIGINT | Surrogate key generated in the warehouse. Use it to join with `fact_sales`. | `1` |
| `customer_id` | INT | Customer id from the CRM. | `11000` |
| `customer_number` | NVARCHAR(50) | Customer code used by both source systems. | `AW00011000` |
| `first_name` | NVARCHAR(50) | First name. | `Jon` |
| `last_name` | NVARCHAR(50) | Last name. | `Yang` |
| `country` | NVARCHAR(50) | Country of residence: Australia, Canada, France, Germany, United Kingdom, United States, or `N/A` when unknown. | `Australia` |
| `marital_status` | NVARCHAR(50) | `Married`, `Single` or `N/A`. | `Married` |
| `gender` | NVARCHAR(50) | `Male`, `Female` or `N/A`. The CRM value is used; the ERP value is used only when the CRM has none. | `Male` |
| `birthdate` | DATE | Date of birth. Empty when the source date was in the future. | `1971-10-06` |
| `create_date` | DATE | Date the customer record was created in the CRM. | `2025-10-06` |

## gold.dim_products

**Purpose:** what is sold. Combines the CRM product record with the category details kept in the ERP. Only the current version of each product is kept; older price versions are left out.

| Column | Type | Description | Example |
|---|---|---|---|
| `product_key` | BIGINT | Surrogate key generated in the warehouse. Use it to join with `fact_sales`. | `1` |
| `product_id` | INT | Product id from the CRM. | `210` |
| `product_number` | NVARCHAR(50) | Product code used in the sales records. | `FR-R92B-58` |
| `product_name` | NVARCHAR(50) | Product name, including colour and size. | `HL Road Frame - Black- 58` |
| `category_id` | NVARCHAR(50) | Category code, taken from the first part of the source product key. | `CO_RF` |
| `category` | NVARCHAR(50) | Accessories, Bikes, Clothing or Components. | `Components` |
| `subcategory` | NVARCHAR(50) | More detailed group inside the category. | `Road Frames` |
| `maintenance` | NVARCHAR(50) | Whether the product needs maintenance: `Yes` or `No`. | `Yes` |
| `cost` | INT | Product cost. `0` when the source had no cost. | `0` |
| `product_line` | NVARCHAR(50) | `Mountain`, `Road`, `Touring`, `Other Sales` or `N/A`. | `Road` |
| `start_date` | DATE | Date this version of the product became valid. | `2003-07-01` |

**Known issue:** 7 pedal products have the category code `CO_PE`, which does not exist in the ERP category list (the list has `CO_PD`, Components / Pedals, with no products). For these 7 products `category`, `subcategory` and `maintenance` are empty. The source was not changed because the correct code could not be confirmed.

## gold.fact_sales

**Purpose:** what was sold, to whom, when and for how much. An order with several products has several rows, one per product: 60,398 rows cover 27,659 orders.

| Column | Type | Description | Example |
|---|---|---|---|
| `order_number` | NVARCHAR(50) | Sales order number. Repeats when the order has more than one product. | `SO43697` |
| `product_key` | BIGINT | Product sold. Points to `gold.dim_products.product_key`. | `20` |
| `customer_key` | BIGINT | Customer who bought. Points to `gold.dim_customers.customer_key`. | `10769` |
| `order_date` | DATE | Date the order was placed. Orders run from 2010-12-29 to 2014-01-28. | `2010-12-29` |
| `shipping_date` | DATE | Date the order was shipped. | `2011-01-05` |
| `due_date` | DATE | Date the payment was due. | `2011-01-10` |
| `sales_amount` | INT | Total value of the line: `quantity` × `price`. | `3578` |
| `quantity` | INT | Units sold in the line. | `1` |
| `price` | INT | Price per unit. | `3578` |

**Known issue:** 19 rows have no `order_date`, because the date in the source was invalid.
