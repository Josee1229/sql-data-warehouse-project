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
