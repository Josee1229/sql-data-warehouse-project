----------------------------------------------------------------------
-- Advance Analytics
----------------------------------------------------------------------


-------------------------------------------------
-- Change Over Time
-------------------------------------------------

-- Analyze Sales Performance Over Time

SELECT
	DATETRUNC(year, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year, order_date)
ORDER BY DATETRUNC(year, order_date);

------ Or----------

SELECT
	FORMAT(order_date, 'yyyy-MMM') AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');


-------------------------------------------------
-- Cumulative Analysis
-------------------------------------------------

-- Calculate the total sales per month
-- and the running total of sales over time

SELECT
*,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total
FROM
(SELECT
	DATETRUNC(month, order_date) AS order_date,
	SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date))t;



------- Year-wise-------------
SELECT
*,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total
FROM
(SELECT
	DATETRUNC(YEAR, order_date) AS order_date,
	SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date))t;

--------------- Moving Average -------------------------

SELECT
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total,
avg_price,
AVG(avg_price) OVER(ORDER BY order_date) AS moving_avg
FROM
(SELECT
	DATETRUNC(YEAR, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date))t;


--------------------------------------------------------------------
-- Performance Analysis (Comparing Current Value to a Target Value)
-- Current[Measure] - Target[Measure]
--------------------------------------------------------------------

/* Analyze the yearly performance of products by comparing their sales
to both the average sales performance of the product and the previous year's sales. */

WITH CTE_yearly_product_sales AS
(
SELECT 
DATETRUNC(YEAR, f.order_date) AS order_year,
p.product_name,
SUM(sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date), p.product_name
)
SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
current_sales - (AVG(current_sales) OVER(PARTITION BY product_name)) AS diff_avg,
CASE WHEN current_sales - (AVG(current_sales) OVER(PARTITION BY product_name)) > 0 THEN 'Above Avg'
	WHEN current_sales - (AVG(current_sales) OVER(PARTITION BY product_name)) < 0 THEN 'Below Avg'
	ELSE 'Avg'
END AS avg_change,
current_sales - (LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year)) AS yearly_change,
CASE WHEN current_sales - (LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year)) > 0 THEN 'Increase'
	WHEN current_sales - (LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year)) < 0 THEN 'Decrease'
	ELSE 'No Change'
END AS py_change
FROM CTE_yearly_product_sales
ORDER BY product_name,order_year;


WITH CTE_Quantity_Year_Analysis AS
(
SELECT
DATETRUNC(YEAR,f.order_date) AS order_year,
p.product_name,
SUM(f.quantity) AS total_qty
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,f.order_date), p.product_name
)
SELECT 
order_year,
product_name,
total_qty,
AVG(total_qty) OVER(PARTITION BY product_name ORDER BY product_name) AS avg_qty,
total_qty - AVG(total_qty) OVER(PARTITION BY product_name ORDER BY product_name) AS avg_diff_qty,
CASE WHEN total_qty - AVG(total_qty) OVER(PARTITION BY product_name ORDER BY product_name) > 0 THEN 'Above Avg'
	WHEN total_qty - AVG(total_qty) OVER(PARTITION BY product_name ORDER BY product_name) < 0 THEN 'Below Avg'
	ELSE 'Avg'
END AS avg_diff_analysis,
LAG(total_qty) OVER(PARTITION BY product_name ORDER BY order_year) AS prv_year_qty,
total_qty - LAG(total_qty) OVER(PARTITION BY product_name ORDER BY order_year) AS prv_year_diff,
CASE WHEN total_qty - LAG(total_qty) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	WHEN total_qty - LAG(total_qty) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	ELSE 'Same'
END AS prv_year_analysis
FROM CTE_Quantity_Year_Analysis
ORDER BY product_name, order_year;


--------------------------------------------------------------------
-- Part to Whole Analysis
-- [Measure]/[Total Measure] * 100 
-------------------------------------------------------------------- 

-- Which categories contribute the most to overall sales?
WITH CTE_category_analysis AS
(
SELECT
p.category,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
on p.product_key = f.product_key
GROUP BY p.category
)
SELECT
category,
total_sales,
SUM(total_sales) OVER() AS aggregate_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) * 100,2), ' %') AS percentage_contribution
FROM CTE_category_analysis
ORDER BY total_sales DESC;


--------------------------------------------------------------------
-- Data Segmentation
-- Group up data based on a specific range. [Measure] By [Measure]
--------------------------------------------------------------------

-- Segment products into cost ranges and count
-- how many products fall into each segment
WITH CTE_product_cost_range AS
(
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	ELSE 'Above 1000'
END cost_range
FROM gold.dim_products
)
SELECT
cost_range,
COUNT(product_key) AS total_products
FROM CTE_product_cost_range
GROUP BY cost_range
ORDER BY total_products DESC;

/* Group customers into three segments based on their spending behaviour:
		- VIP : Customers with at least 12 months of history and spending more than 5,000.
		- Regular: Customers with at least 12 months of history but spending 5,000 or Less.
		- New: Customers with a lifespan less than 12 months.
*/

SELECT
c.customer_key,
c.first_name,
c.last_name,
DATEDIFF(month,MIN(f.order_date), GETDATE()) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
GROUP BY 
c.customer_key,
c.first_name,
c.last_name;

WITH CTE_Customer_Lifespan_and_sales AS
(
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(f.order_date)  AS first_order,
MAX(f.order_date) AS Last_order,
DATEDIFF(MONTH,MIN(f.order_date),MAX(f.order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
on c.customer_key = f.customer_key
GROUP BY c.customer_key
),
CTE_Customer_cat AS(
SELECT
customer_key,
total_spending,
lifespan,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
	WHEN lifespan >=12 AND total_spending <=5000 THEN 'Regular'
	ELSE 'New'
END AS customer_cat
FROM CTE_Customer_Lifespan_and_sales
)
SELECT
customer_cat,
COUNT(*) AS no_of_customers
FROM CTE_Customer_cat
GROUP BY customer_cat;

--------------------------------------------------------------------
-- Reporting
--------------------------------------------------------------------

/*
========================================================================
Customer Report
========================================================================
Purpose:
	- This report consolidates key customer metrics and behaviours.

Highlights:
	1. Gather essential fields such as names, ages, and transactional details.
	2. Segment customers into categories (VIP, Regular, New) and age groups.
	3. Aggregate customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculate valuabe KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
========================================================================
*/
CREATE VIEW gold.report_customers AS
WITH CTE_base_query AS
(
SELECT
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name,' ',c.last_name) AS customer_name,
DATEDIFF(YEAR,c.birth_date,GETDATE()) AS customer_age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
), CTE_customer_aggregations AS
(
SELECT 
customer_key,
customer_number,
customer_name,
customer_age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM CTE_base_query
GROUP BY
	customer_key,
	customer_number,
	customer_name,
	customer_age
)
SELECT 
	customer_key,
	customer_number,
	customer_name,
	customer_age,
		CASE WHEN customer_age < 20 THEN 'Under 20'
			WHEN customer_age BETWEEN 20 AND 29 THEN '20-29'
			WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
			WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
		ELSE '50 and above'
		END AS age_group,
		CASE
			WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
			WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
			ELSE 'New'
		END AS customer_segment,
	last_order_date,
	DATEDIFF(MONTH,last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan,
	-- Compute Average order value (AVO)
	CASE WHEN total_orders = 0 THEN 0 
		ELSE total_sales / total_orders 
	END AS avg_order_value,

	-- Compute average monthly spend
	CASE WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_spend
FROM CTE_customer_aggregations;



SELECT 
age_group,
COUNT(customer_number) AS total_customers,
SUM(total_sales) AS total_sales
FROM gold.report_customers
GROUP BY age_group;


/*
=========================================================================================
Product Report
=========================================================================================
Purpose:
	- This report consolidates key product metrics and behavious.

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-performers.
	3. Aggregagtes product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	4. Calculate valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
=============================================================================================
*/

-- product name, category, subcategory, and cost.


CREATE OR ALTER VIEW gold.report_products AS
WITH CTE_Product_Base AS
(SELECT
f.product_key,
p.product_name,
p.category,
p.subcategory,
p.start_date,
f.customer_key,
f.order_number,
f.order_date,
f.sales_amount,
f.quantity
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
), CTE_Product_Aggregations AS
(
SELECT
product_key,
product_name,
category,
subcategory,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT customer_key) AS total_customers,
DATEDIFF(MONTH, MAX(order_date),MAX(order_date)) AS lifespan,
DATEDIFF(MONTH,MAX(order_date),GETDATE()) AS recency
FROM CTE_Product_Base
GROUP BY
	product_key,
	product_name,
	category,
	subcategory
)
SELECT
product_key,
product_name,
category,
subcategory,
total_orders,
total_sales,
CASE 
	WHEN total_sales <= 99000 THEN 'Low Performer'
	WHEN total_sales BETWEEN 100000 AND 500000 THEN 'Mid Range'
	ELSE 'High Performer'
END AS revenue_segment,
total_quantity,
total_customers,
lifespan,
recency,
-- Average order Revenue
CASE WHEN total_orders = 0 THEN 0
	ELSE total_sales / total_orders
END AS avg_order_revenue,
-- Average monthly revenue
CASE WHEN lifespan = 0 THEN total_sales
	ELSE total_sales / lifespan
END AS avg_monthly_revenue
FROM CTE_Product_Aggregations;
