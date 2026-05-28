/*
==========================================================
Project: WarehouseAnalytics Portfolio
Database: WarehouseAnalytics

Purpose:
This script creates a lyerd analytics database using 
bronze, silver, and gold schemas.

Bronze Layer: 
- Stored raw CSV data

Silver Layer: 
- Cleans and standardizes selected data columns.
- Handles duplicate customer records, email validation,
  join_date formatting, order quantity validation, and 
  product category formatting.

Gold Layer:
- Create reporting-ready dimension, fact, and KPI views
  for Tableau dashboard analysis.

Dashboard Focus:
- Sales performance
- Return analysis
- Inventory status
- Warehouse process efficiency
==========================================================
*/
--------------------------------------------------
-- 1. Create Database and schema structure
--------------------------------------------------
--CREATE DATABASE WarehouseAnalytics;
--GO

--USE WarehouseAnalytics;
--GO

--CREATE SCHEMA bronze;
--CREATE SCHEMA silver;
--CREATE SCHEMA gold;
--GO

--------------------------------------------------
-- 2. Create bronze tables and insert data from csv
--------------------------------------------------
CREATE TABLE bronze.customers (
    customer_id INT,
    name VARCHAR(200),
	email VARCHAR(100),
    region VARCHAR(50),
    join_date VARCHAR(50) --Row CSV value, convert to DATE in silver layer
);
GO

BULK INSERT bronze.customers
FROM 'C:\projects\WarehouseAnalytics\data\customers.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.employees (
    employee_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(50),
    shift VARCHAR(30),
    hire_date DATE
);
GO

BULK INSERT bronze.employees
FROM 'C:\projects\WarehouseAnalytics\data\employees.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.inventory (
    inventory_id INT,
    product_id INT,
    quantity_on_hand INT,
    last_updated DATETIME2(0)
);
GO

BULK INSERT bronze.inventory
FROM 'C:\projects\WarehouseAnalytics\data\inventory.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.order_details (
    order_detail_id INT,
    order_id INT,
    product_id INT,
    quantity VARCHAR(10),
    unit_price VARCHAR(50),
    discount VARCHAR(50)
);
GO

BULK INSERT bronze.order_details
FROM 'C:\projects\WarehouseAnalytics\data\order_details.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.order_process_stages (
    stage_id INT,
    order_id INT,
    stage_name VARCHAR(50),
    employee_id INT,
    start_time DATETIME2(0),
    end_time DATETIME2(0)
);
GO

BULK INSERT bronze.order_process_stages
FROM 'C:\projects\WarehouseAnalytics\data\order_process_stages.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.orders (
    order_id INT,
    customer_id INT,
    employee_id INT,
    order_date DATETIME2(0),
    status VARCHAR(30),
    shipped_date DATETIME2(0) NULL,
    total_amount DECIMAL(18, 4),
    start_time DATETIME2(0),
    end_time DATETIME2(0)
);
GO

BULK INSERT bronze.orders
FROM 'C:\projects\WarehouseAnalytics\data\orders.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.products (
    product_id INT,
    product_name VARCHAR(200),
    category VARCHAR(50),
    unit_cost VARCHAR(50),
    unit_price VARCHAR(50),
    reorder_level VARCHAR(50),
    supplier VARCHAR(200)
);
GO

BULK INSERT bronze.products 
FROM 'C:\projects\WarehouseAnalytics\data\products.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.receipts (
    receipt_id INT,
    product_id INT,
    employee_id INT,
    received_date DATETIME2(0),
    quantity_received INT,
    supplier VARCHAR(200),
    receipt_status VARCHAR(50)
);
GO

BULK INSERT bronze.receipts 
FROM 'C:\projects\WarehouseAnalytics\data\receipts.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

CREATE TABLE bronze.returns (
    return_id INT,
    order_id INT,
    product_id INT,
    customer_id INT,
    return_date DATETIME2(0),
    reason VARCHAR(100),
    quantity INT
);
GO

BULK INSERT bronze.returns  
FROM 'C:\projects\WarehouseAnalytics\data\returns.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    --FIELDQUOTE = '"',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
)
GO

--------------------------------------------------
-- 3. Validate data was inserted successfully
--------------------------------------------------

SELECT TOP 10 * FROM [bronze].[customers]
SELECT TOP 10 * FROM [bronze].[employees]
SELECT TOP 10 * FROM [bronze].[inventory]
SELECT TOP 10 * FROM [bronze].[order_details]
SELECT TOP 10 * FROM [bronze].[order_process_stages]
SELECT TOP 10 * FROM [bronze].[orders]
SELECT TOP 100 * FROM [bronze].[products]
SELECT TOP 10 * FROM [bronze].[receipts]
SELECT TOP 10 * FROM [bronze].[returns]
GO

--DROP TABLE [bronze].[customers]
--DROP TABLE [bronze].[employees]
--DROP TABLE [bronze].[inventory]
--DROP TABLE [bronze].[order_details]
--DROP TABLE [bronze].[order_process_stages]
--DROP TABLE [bronze].[orders]
--DROP TABLE [bronze].[products]
--DROP TABLE [bronze].[receipts]
--DROP TABLE [bronze].[returns]
--GO
--------------------------------------------------
-- 4. Create silver layer: data cleansing
--------------------------------------------------

--Validate email, standardize date format, remove duplicate records
CREATE OR ALTER VIEW silver.customers AS
WITH deduplicated_customers AS (
	SELECT *,
		   ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY customer_id) AS rn
	FROM bronze.customers
)
SELECT
    customer_id,
    name,
	email as raw_email,
    CASE WHEN NULLIF(TRIM(email),'') IS NULL THEN NULL
		 WHEN TRIM(email) LIKE ('%@%.%')
			THEN LOWER(TRIM(email)) --handle space and blank
		 ELSE NULL
	END AS clean_email,
    CASE WHEN NULLIF(TRIM(email),'') IS NULL THEN 'BLANK'
		 WHEN TRIM(email) NOT LIKE ('%@%.%') THEN 'INVALID_FORMAT'
		 ELSE 'VALID'
	END AS email_validation_status,
    region,
    TRY_CONVERT(date, TRIM(NULLIF(join_date,''))) AS join_date
FROM deduplicated_customers
WHERE rn = 1;
GO

--Validate order quantity
CREATE OR ALTER VIEW silver.order_details AS
WITH cleansed_order_details AS (
SELECT 
	order_detail_id,
	order_id,
	product_id,
	quantity as raw_quantity,
	TRY_CONVERT(DECIMAL(18,2), TRIM(quantity)) as quantity_decimal,
	TRY_CONVERT(DECIMAL(18,2), TRIM(unit_price)) AS unit_price,
	TRY_CONVERT(DECIMAL(5,4), TRIM(discount)) AS discount
FROM [bronze].[order_details]
)
SELECT 
	order_detail_id,
	order_id,
	product_id,
	raw_quantity,
	CASE WHEN quantity_decimal IS NULL THEN 0 
		 WHEN quantity_decimal < 0 THEN 0 
		 WHEN quantity_decimal % 1 <> 0 THEN 0 
		 ELSE CONVERT(int, quantity_decimal)
	END AS clean_quantity,
	CASE WHEN quantity_decimal IS NULL THEN 'TEXT'
		 WHEN quantity_decimal < 0 THEN 'NEGATIVE_NUMBER'
		 WHEN quantity_decimal % 1 <> 0 THEN 'DECIMAL_NUMBER'
		 ELSE 'VALID'
	END AS quantity_validation_status,
	unit_price,
	discount
FROM cleansed_order_details;
GO

-- Format inconsistent text
CREATE OR ALTER VIEW silver.products AS
SELECT 
	product_id,
	TRIM(product_name) AS product_name,
	CASE WHEN NULLIF(TRIM(category), '') IS NULL THEN 'Unknown'
		 ELSE CONCAT(
				UPPER(LEFT(TRIM(category),1)), 
				LOWER(RIGHT(TRIM(category), LEN(TRIM(category))-1))
				) 
	END AS category,
	TRY_CONVERT(DECIMAL(18,2), TRIM(unit_cost)) AS unit_cost,
	TRY_CONVERT(DECIMAL(18,2), TRIM(unit_price)) AS unit_price,
	TRY_CONVERT(INT, TRIM(reorder_level)) AS reorder_level,
	supplier
FROM [bronze].[products];
GO

-- Check the views created
SELECT TOP 10 * FROM silver.customers;
SELECT TOP 10 * FROM silver.order_details;
SELECT TOP 10 * FROM silver.products;
GO
--------------------------------------------------
-- 5. Create gold layer: summary for Tableau use
--------------------------------------------------

-- Customer dimension
CREATE OR ALTER VIEW gold.dim_customer AS
SELECT 
	customer_id,
	name as customer_name,
	clean_email as email,
	region,
	join_date
FROM silver.customers
GO

-- Product dimension
CREATE OR ALTER VIEW gold.dim_product AS
SELECT 
	product_id,
	product_name,
	category,
	supplier,
	unit_cost,
	unit_price,
	reorder_level
FROM silver.products
GO

-- Employee dimension
CREATE OR ALTER VIEW gold.dim_employee AS
SELECT
    employee_id,
	CONCAT(first_name, ' ', last_name) AS employee_name,
	role,
	shift,
	hire_date
FROM bronze.employees;
GO

-- Sales fact table with discount, cost, and gross profit calculations
CREATE OR ALTER VIEW gold.fact_sales AS
SELECT 
	o.order_id,
	od.order_detail_id,
	o.customer_id,
	od.product_id,
	CAST(o.order_date AS DATE) AS order_date,
	od.clean_quantity AS quantity,
	od.unit_price,
	od.discount,
	od.clean_quantity * od.unit_price AS sales_before_discount,
	CAST(od.clean_quantity * od.unit_price * ISNULL(od.discount,0) AS DECIMAL(18,2)) AS discount_amount,
	CAST(od.clean_quantity * od.unit_price * (1-ISNULL(od.discount,0)) AS DECIMAL(18,2)) AS net_sales_amount,
	od.clean_quantity * p.unit_cost AS total_cost,
	CAST(
		od.clean_quantity * od.unit_price * (1-ISNULL(od.discount,0))
			- od.clean_quantity * p.unit_cost 
		 AS DECIMAL(18,2))
	AS gross_profit
FROM bronze.orders o
INNER JOIN silver.order_details od
	ON o.order_id = od.order_id
INNER JOIN silver.products p
	ON od.product_id = p.product_id
WHERE od.quantity_validation_status = 'VALID';
GO

-- Return fact table
CREATE OR ALTER VIEW gold.fact_returns AS
SELECT 
	return_id,
	order_id,
	product_id,
	customer_id,
	CAST(return_date AS DATE) as return_date,
	reason AS return_reason,
	quantity AS return_quantity
FROM bronze.returns;
GO

-- Order_Process fact table
CREATE OR ALTER VIEW gold.fact_order_process AS
SELECT 
	stage_id,
	order_id,
	stage_name,
	employee_id,
	start_time,
	end_time,
	DATEDIFF(MINUTE, start_time, end_time) AS process_minutes
FROM bronze.order_process_stages;
GO

-- Inventory fact table
CREATE OR ALTER VIEW gold.fact_inventory AS
SELECT 
	i.product_id,
	p.product_name,
	p.category,
	i.quantity_on_hand,
	p.reorder_level,
	CASE WHEN i.quantity_on_hand <= p.reorder_level THEN 1
		 ELSE 0
	END AS below_reorder_level_flag,
	CAST(i.quantity_on_hand * p.unit_cost AS DECIMAL(18, 2)) AS inventory_value
FROM bronze.inventory i
INNER JOIN silver.products p
	ON i.product_id = p.product_id;
GO

-- Sales KPI summary with total orders, units, and gross profit margin
CREATE OR ALTER VIEW gold.kpi_sales_summary AS
SELECT
 CAST(SUM(net_sales_amount) AS DECIMAL(18,2)) AS total_sales,
 COUNT(DISTINCT order_id) AS total_orders,
 SUM(quantity) AS total_units_sold,
 CAST(SUM(gross_profit) AS DECIMAL(18,2)) AS total_gross_profit,
 CAST(
	SUM(gross_profit) / NULLIF(SUM(net_sales_amount), 0)
	AS DECIMAL(18, 4)
 ) AS gross_profit_margin
FROM gold.fact_sales;
GO

-- Return KPI summary using valid returns linked to sales records
CREATE OR ALTER VIEW gold.kpi_return_summary AS
WITH sales_qty AS (
	SELECT SUM(quantity) AS total_order_quantity
	FROM gold.fact_sales
),
return_qty AS (
	SELECT 	COUNT(DISTINCT r.return_id) AS total_returns,
			SUM(r.return_quantity) AS total_return_quantity
	FROM gold.fact_returns r
	WHERE EXISTS (
		SELECT 1 
		FROM gold.fact_sales s
		WHERE r.order_id = s.order_id
		AND r.product_id = s.product_id
	)
)
SELECT
	r.total_returns,
	r.total_return_quantity,
	total_order_quantity,
	CAST(
		total_return_quantity * 1.0 / NULLIF(total_order_quantity, 0) 
		AS decimal(18,4)
	) AS return_rate_by_quantity
FROM return_qty r
CROSS JOIN sales_qty s
GO

-- Check the views created
SELECT TOP 10 * FROM gold.dim_customer;
SELECT TOP 10 * FROM gold.dim_product;
SELECT TOP 10 * FROM gold.dim_employee;
SELECT TOP 10 * FROM gold.fact_sales;
SELECT TOP 10 * FROM gold.fact_order_process;
SELECT TOP 10 * FROM gold.fact_inventory;
SELECT TOP 10 * FROM gold.fact_returns;
SELECT TOP 10 * FROM gold.kpi_sales_summary;
SELECT TOP 10 * FROM gold.kpi_return_summary;
GO

--------------------------------------------------
-- 5. Export gold views to CSV for Tableau use
--------------------------------------------------
-- Check the views created
SELECT * FROM gold.dim_customer;
SELECT * FROM gold.dim_product;
SELECT * FROM gold.dim_employee;
SELECT * FROM gold.fact_sales;
SELECT * FROM gold.fact_order_process;
SELECT * FROM gold.fact_inventory;
SELECT * FROM gold.fact_returns;
GO