-- Purpose: Creates the DataWarehouse database and the bronze, silver, and gold Schemas.
-- WARNING: Drops DataWarehouse Database if it already exists.

USE master;

GO

DROP DATABASE IF EXISTS DataWarehouse;

GO

CREATE DATABASE DataWarehouse;

GO

USE Datawarehouse;

GO

CREATE SCHEMA bronze;

GO

CREATE SCHEMA silver;

GO

CREATE SCHEMA gold;