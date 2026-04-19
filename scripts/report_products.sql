
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
