/*
==============================================================
Quality Checks
==============================================================
Script Purpose:
    This script performs various quality checks for data consistency,
    accuracy, and standardization across the 'silver' schema. It includes checks for
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid data ranges and orders.
    - Data consistency between related fields.

Usage Notes:
  - Run these checks after loading data into the Silver Layer.
  - Investigate and resolve any discrepancies found during the checks. 
*/


/*==============================================================
  1. CUSTOMER MASTER CHECKS
  Table: silver.crm_cust_info
==============================================================*/

-- Check NULLs or Duplicate Primary Keys
-- Expectation: No Result
SELECT 
    cst_id,
    COUNT(*) AS record_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;


-- Check unwanted leading/trailing spaces in last name
-- Expectation: No Result
SELECT 
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname <> TRIM(cst_lastname);


-- Validate Gender Standardization
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;


-- Validate Marital Status Standardization
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;



/*==============================================================
  2. PRODUCT MASTER CHECKS
  Table: silver.crm_prd_info
==============================================================*/

-- Check NULLs or Duplicate Product IDs
-- Expectation: No Result
SELECT 
    prd_id,
    COUNT(*) AS record_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;


-- Check NULLs or Duplicate Product Keys
-- Expectation: No Result
SELECT 
    prd_key,
    COUNT(*) AS record_count
FROM silver.crm_prd_info
GROUP BY prd_key
HAVING COUNT(*) > 1 OR prd_key IS NULL;


-- Investigate specific duplicate product key if needed
SELECT *
FROM silver.crm_prd_info
WHERE prd_key = 'AC-HE-HL-U509';


-- Check unwanted spaces in Product Name
-- Expectation: No Result
SELECT 
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm <> TRIM(prd_nm);


-- Check NULL or Negative Product Cost
-- Expectation: No Result
SELECT 
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL
   OR prd_cost < 0;


-- Validate Product Line Standardization
SELECT DISTINCT prd_line
FROM silver.crm_prd_info;


-- Check invalid date ranges
-- Product End Date should not be before Start Date
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- Validate historical product versions using Bronze Layer
SELECT
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prd_end_dt,
    LEAD(prd_start_dt) OVER (
        PARTITION BY prd_key
        ORDER BY prd_start_dt
    ) - 1 AS expected_end_dt
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509');


-- Full Product Table Review
SELECT *
FROM silver.crm_prd_info;



/*==============================================================
  3. SALES FACT CHECKS
  Table: silver.crm_sales_details
==============================================================*/

-- Check unwanted spaces in Sales Order Number
-- Expectation: No Result
SELECT 
    sls_ord_num
FROM silver.crm_sales_details
WHERE sls_ord_num <> TRIM(sls_ord_num);


-- Check orphan customer IDs
-- Sales customer should exist in customer master
SELECT *
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (
    SELECT cst_id
    FROM silver.crm_cust_info
);


-- Check invalid Due Dates in Bronze Layer
SELECT 
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LEN(sls_due_dt) < 8
   OR sls_due_dt > 20500101
   OR sls_due_dt < 19000101;


-- Validate Sales Amount Logic
-- Formula: sales = quantity * price
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- Check invalid order lifecycle dates
-- Order Date should be <= Ship Date and Due Date
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;


-- Full Sales Table Review
SELECT *
FROM silver.crm_sales_details;



/*==============================================================
  4. ERP CUSTOMER CHECKS
  Table: silver.erp_cust_az12
==============================================================*/

-- Check duplicate customer IDs
SELECT
    cid,
    COUNT(*) AS record_count
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1;


-- Check NULL Birth Dates
SELECT *
FROM silver.erp_cust_az12
WHERE bdate IS NULL;


-- Validate Gender Standardization
SELECT DISTINCT gen
FROM silver.erp_cust_az12;


-- Check future Birth Dates
SELECT DISTINCT bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE();


-- Full ERP Customer Table Review
SELECT *
FROM silver.erp_cust_az12;



/*==============================================================
  5. ERP LOCATION CHECKS
  Table: silver.erp_loc_a101
==============================================================*/

-- Validate Country Values
SELECT DISTINCT cntry
FROM silver.erp_loc_a101;


-- Full Location Table Review
SELECT *
FROM silver.erp_loc_a101;



/*==============================================================
  6. ERP PRODUCT CATEGORY CHECKS
  Table: silver.erp_px_cat_g1v2
==============================================================*/

-- Full Product Category Table Review
SELECT *
FROM silver.erp_px_cat_g1v2;



/*==============================================================
  END OF DATA QUALITY SCRIPT
==============================================================*/
