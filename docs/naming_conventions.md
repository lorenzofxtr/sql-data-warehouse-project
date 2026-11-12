# Naming Conventions

The rules used for every object in the warehouse. All names are in English, lower case, with words separated by underscores (`snake_case`).

## Schemas

One schema per layer: `bronze`, `silver`, `gold`.

## Tables and views

| Layer | Pattern | Example | Why |
|---|---|---|---|
| Bronze | `<source>_<entity>`, entity named as in the source file | `bronze.crm_cust_info` | The name shows at a glance which system the data came from, and matches the file it was loaded from. |
| Silver | Same name as in bronze | `silver.crm_cust_info` | Each silver table is the cleaned version of one bronze table. |
| Gold | `dim_<entity>` for dimensions, `fact_<entity>` for facts, with business names | `gold.dim_customers`, `gold.fact_sales` | Gold is read by people doing analysis, so the names describe the business and not the source system. |

`<source>` is `crm` or `erp`.

## Columns

| Kind | Pattern | Example |
|---|---|---|
| Bronze and silver columns | Kept as in the source | `cst_firstname`, `sls_order_dt` |
| Gold columns | Full, readable words | `first_name`, `order_date` |
| Surrogate keys (created in the warehouse) | `<entity>_key` | `customer_key`, `product_key` |
| Technical columns added by the warehouse | Prefix `dwh_` | `dwh_create_date` |

## Stored procedures

`load_<layer>`: `bronze.load_bronze`, `silver.load_silver`.

## Script files

| Prefix | Contains | Example |
|---|---|---|
| `ddl_` | The `CREATE` statements of a layer | `ddl_silver.sql` |
| `proc_load_` | The procedure that loads a layer | `proc_load_silver.sql` |
| `quality_checks_` | Read-only checks for a layer | `quality_checks_silver.sql` |

Every script starts with a `Purpose` line and a `WARNING` line that says what it deletes, if anything.
