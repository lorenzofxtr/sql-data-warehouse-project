# Datasets

The six source files of the warehouse, exactly as provided. They are loaded into the bronze layer by `bronze.load_bronze`.

| File | System | Content | Rows |
|---|---|---|---|
| `source_crm/cust_info.csv` | CRM | Customers | 18,494 |
| `source_crm/prd_info.csv` | CRM | Products, with their price history | 397 |
| `source_crm/sales_details.csv` | CRM | Sales order lines | 60,398 |
| `source_erp/CUST_AZ12.csv` | ERP | Customer birthdate and gender | 18,484 |
| `source_erp/LOC_A101.csv` | ERP | Customer country | 18,484 |
| `source_erp/PX_CAT_G1V2.csv` | ERP | Product categories | 37 |

The files are not changed here, including their problems: the cleaning is done in the silver layer, and the problems found are listed in the main [README](../README.md).

## Source

The dataset comes from the course [SQL Data Warehouse from Scratch](https://github.com/DataWithBaraa/sql-data-warehouse-project) by Data with Baraa, published under the MIT License. The license text is in [LICENSE](LICENSE).
