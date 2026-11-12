# Southline Cycles Data Warehouse

A SQL Server data warehouse that takes sales data from two source systems (a CRM and an ERP, delivered as CSV files), cleans it, and turns it into a star schema ready for reporting.

This is a study project. I built it step by step in SQL Server, following the course [SQL Data Warehouse from Scratch](https://www.youtube.com/watch?v=9GVqKuTVANE) by Data with Baraa. The dataset and the design come from the course. The section on source data problems records what the cleaning found, including two problems I recorded instead of fixing.

## How it is built

The warehouse has three layers. Each one does a single job:

| Layer | Job | Objects | How it is loaded |
|---|---|---|---|
| **Bronze** | Keep the source data exactly as it arrived | 6 tables | `EXEC bronze.load_bronze` (truncate and bulk insert from the CSV files) |
| **Silver** | Clean and standardize | 6 tables | `EXEC silver.load_silver` (truncate and insert from bronze) |
| **Gold** | Business-ready data for reports | 3 views | Nothing to load: the views read from silver |

![Data flow: sources, bronze, silver and gold](docs/data_flow.png)

The architecture, with what each layer does and does not do, is in [docs/data_architecture.md](docs/data_architecture.md).

## The data model

The gold layer is a star schema: one fact (sales) and two dimensions (customers and products).

![Star schema of the gold layer](docs/data_model.png)

Every column is described in the [data catalog](docs/data_catalog.md).

The two source systems describe the same customers and products with different keys. This is how the six source tables connect, and which business object each one belongs to:

![Integration model: how the source tables are related](docs/data_integration.png)

## Problems found in the source data

Most of the work in this project was finding out what was wrong with the data and deciding what to do about it. The counts were measured on the loaded data.

| Problem | Where | Size | What the warehouse does |
|---|---|---|---|
| Customers with no id | CRM customers | 3 rows | Dropped |
| Same customer id in more than one row | CRM customers | 5 ids (11 rows) | Keeps the most recent record |
| Extra spaces around names | CRM customers | 26 rows | Trimmed |
| No gender in the CRM | CRM customers | 4,569 customers | Uses the ERP gender when it has one (4,554 filled; 15 stay `N/A`) |
| CRM and ERP disagree on gender | CRM and ERP customers | 57 customers | The CRM value wins |
| Customer ids with a `NAS` prefix | ERP customers | 11,042 of 18,483 rows | Prefix removed so the ids match the CRM |
| Customer ids with a hyphen | ERP locations | all 18,484 rows | Hyphen removed so the ids match the CRM |
| Birthdates in the future | ERP customers | 16 rows | Set to empty |
| Gender and country written in several ways (`F`, `Female`, `US`, `USA`, blank...) | ERP customers and locations | 6 and 11 variations | One readable value each; blanks become `N/A` |
| End date earlier than start date | CRM products | 200 of 397 rows | End date rebuilt as the day before the next version starts |
| Missing cost | CRM products | 2 rows | Set to 0 |
| Invalid order date | CRM sales | 19 rows | Set to empty |
| Sales amount or price missing, zero, negative, or not matching quantity × price | CRM sales | 35 rows | Recalculated so that sales = quantity × price |

Two problems were **recorded and left as they are**, because fixing them needs an answer from whoever owns the source:

- **Category code `CO_PE` does not exist in the ERP.** Seven pedal products in the CRM use `CO_PE`. The ERP category list has `CO_PD` (Components / Pedals) and no product uses it. They are probably the same category typed two ways, but I could not confirm which code is right, so the seven products have no category in `gold.dim_products`. Recommendation: confirm the code with the ERP owner and correct it in the source.
- **The last line of two CSV files is not loaded.** `cust_info.csv` and `CUST_AZ12.csv` do not end with a line break and their last line ends in an empty field, so `BULK INSERT` skips it. In `cust_info.csv` the line is junk (it has no customer id). In `CUST_AZ12.csv` it is a real customer, `AW00029483`, who therefore has no birthdate in the warehouse. Recommendation: have the source system end its files with a line break.

## Repository

```
datasets/                      source CSV files go here (not included, see below)
docs/
    data_architecture.md       the three layers
    data_catalog.md            every column of the gold views
    data_flow.png              where each table comes from
    data_integration.png       how the source tables are related
    data_model.png             the star schema
scripts/
    init_database.sql          creates the database and the three schemas
    bronze/
        ddl_bronze.sql         creates the bronze tables
        proc_load_bronze.sql   creates bronze.load_bronze
    silver/
        ddl_silver.sql         creates the silver tables
        proc_load_silver.sql   creates silver.load_silver
        quality_checks_silver.sql   checks used to find and confirm the fixes
    gold/
        ddl_gold.sql           creates the three gold views
```

## Running it

You need SQL Server (the free Express edition is enough) and SQL Server Management Studio.

1. Get the six CSV files from the `01_datasets` folder of the [course repository](https://github.com/DataWithBaraa/sql-data-warehouse-project).
2. Run `scripts/init_database.sql`. It drops the `DataWarehouse` database if it already exists.
3. Run `scripts/bronze/ddl_bronze.sql`.
4. Open `scripts/bronze/proc_load_bronze.sql`, change the six file paths to where you saved the CSV files, and run it. Then run `EXEC bronze.load_bronze;`.
5. Run `scripts/silver/ddl_silver.sql` and `scripts/silver/proc_load_silver.sql`. Then run `EXEC silver.load_silver;`.
6. Run `scripts/gold/ddl_gold.sql`.

To check the result: `SELECT COUNT(*) FROM gold.fact_sales;` returns 60,398.

## License

[MIT](LICENSE). The dataset comes from the course by Data with Baraa.
