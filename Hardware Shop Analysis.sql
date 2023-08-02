/* 
Croma India Product wise sales report for Fiscal Year 2021. The report must have columns :
1. Month 
2. Product Name
3. Variant
4. Sold Quantity
5. Gross Price Per Item
6. Gross Price Total 
*/

SELECT 
    monthname(fsm.date) as month,
    fsm.product_code,
    dp.product,
    dp.variant,
    fsm.sold_quantity,
    fgp.gross_price,
    ROUND((fgp.gross_price * fsm.sold_quantity), 2) AS gross_price_total
FROM
    fact_sales_monthly fsm
        JOIN
    dim_product dp USING (product_code)
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = GET_FISCAL_YEAR(fsm.date)
WHERE
    customer_code = '90002002'
        AND GET_FISCAL_YEAR(date) = 2021
ORDER BY date
LIMIT 1000000;


/*
Gross monthly total sales report for Croma. Required Columns:
1. Month
2. Total gross sales amount to Croma India this month.
*/


SELECT 
    fsm.date,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price),
            2) AS gross_price_total
FROM
    fact_sales_monthly fsm
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = GET_FISCAL_YEAR(fsm.date)
WHERE
    customer_code = '90002002'
GROUP BY fsm.date
ORDER BY fsm.date DESC
LIMIT 1000000;


/*
Generate a yearly report for Croma India where there are two columns:
1. Fiscal Year
2. Total Gross Sales amount in that year from Croma.
*/

SELECT 
    GET_FISCAL_YEAR(fsm.date) AS Fiscal_Year,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price),
            2) AS Yearly_Sales
FROM
    fact_sales_monthly fsm
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = GET_FISCAL_YEAR(fsm.date)
WHERE
    customer_code = '90002002'
GROUP BY GET_FISCAL_YEAR(fsm.date)
ORDER BY Fiscal_year;



/* 
Create a stored procedure for Customer wise Monthly Sales Report.
*/

-- Report for Atliq Exclusive 

call get_monthly_sales_report(70002017);

-- Report for Lotus

call get_monthly_sales_report(90002005);

-- Report for Ezone

call get_monthly_sales_report(90002003);

-- Combined Report for Atliq Exclusive and Lotus

call get_monthly_sales_report("70002017,90002005");


/* 
Create a stored procedure to generate a financial report of market in a particular fiscal year.
The report must contain:
1. Market
2. Fiscal Year 
as input and 
1. yearly Sales
as output.
*/

/*
set @badge = '0';
call gdb0041.get_market_badge('china', 2021, @badge);
select @badge;
*/

/* 
Query Optimisation
*/

-- Total execution time 21.79 seconds
Explain ANALYZE
SELECT 
    MONTHNAME(fsm.date) AS month,
    fsm.product_code,
    dp.product,
    dp.variant,
    fsm.sold_quantity,
    fgp.gross_price,
    ROUND((fgp.gross_price * fsm.sold_quantity), 2) AS gross_price_total
FROM
    fact_sales_monthly fsm
        JOIN
    dim_product dp USING (product_code)
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = GET_FISCAL_YEAR(fsm.date)
WHERE
    GET_FISCAL_YEAR(date) = 2021
ORDER BY date
LIMIT 100000000;


-- Total execution time 2.7 seconds. Optimised by adding a new table dim_date in order to remove the get_fiscal_year function.
Explain ANALYZE
SELECT 
    MONTHNAME(fsm.date) AS month,
    fsm.product_code,
    dp.product,
    dp.variant,
    fsm.sold_quantity,
    fgp.gross_price,
    ROUND((fgp.gross_price * fsm.sold_quantity), 2) AS gross_price_total
FROM
    fact_sales_monthly fsm
        JOIN
    dim_product dp USING (product_code)
        JOIN
    dim_date dd ON dd.calendar_date = fsm.date
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = dd.fiscal_year
WHERE
    dd.fiscal_year = 2021
ORDER BY date
LIMIT 100000000;



-- Total execution time 1.6 seconds. Optimised by adding a new column fiscal_year in the fact_sales_monthly itself.
ALTER TABLE fact_sales_monthly
Add column fiscal_year year generated always as (year(date_add(date, interval 4 month)));

EXPLAIN ANALYZE
SELECT 
    MONTHNAME(fsm.date) AS month,
    fsm.product_code,
    dp.product,
    dp.variant,
    fsm.sold_quantity,
    fgp.gross_price,
    ROUND((fgp.gross_price * fsm.sold_quantity), 2) AS gross_price_total
FROM
    fact_sales_monthly fsm
        JOIN
    dim_product dp USING (product_code)
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = fsm.fiscal_year
WHERE
    fsm.fiscal_year = 2021
ORDER BY date
LIMIT 100000000;


-- Get net invoice sales of each product

# Method 1 using CTE: 

with pre_dct as (
SELECT 
    fsm.date,
    fsm.product_code,
    dp.product,
    dp.variant,
    fsm.sold_quantity,
    fgp.gross_price,
    ROUND((fgp.gross_price * fsm.sold_quantity), 2) AS gross_price_total,
    pre.pre_invoice_discount_pct
FROM
    fact_sales_monthly fsm
        JOIN
    dim_product dp USING (product_code)
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = fsm.fiscal_year
        JOIN
    fact_pre_invoice_deductions AS pre ON pre.customer_code = fsm.customer_code
        AND pre.fiscal_year = fsm.fiscal_year
WHERE
    fsm.fiscal_year = 2021
ORDER BY date
LIMIT 1000000000)

select *, (gross_price_total - (gross_price_total * pre_invoice_discount_pct)) as net_invoice_sales from pre_dct;

#Method 2 using views
-- Created a view named sales_preinv_discount
SELECT 
    *,
    (gross_price_total - (gross_price_total * pre_invoice_discount_pct)) AS net_invoice_sales
FROM
    sales_preinv_discount;


-- Calculating post invoice_discount 

#Method 1 using CTE

with sales_postinv_discount_cte as (
SELECT 
    pre.date,
    pre.fiscal_year,
    pre.customer_code,
    pre.market,
    pre.product_code,
    pre.product,
    pre.variant,
    pre.sold_quantity,
    pre.gross_price_per_item,
    pre.gross_price_total,
    pre.pre_invoice_discount_pct,
    (1 - pre.pre_invoice_discount_pct) * pre.gross_price_total AS net_invoice_sales,
    (post.discounts_pct + post.other_deductions_pct) AS post_invoice_discount_pct
FROM
    sales_preinv_discount pre
        JOIN
    fact_post_invoice_deductions post ON pre.date = post.date
        AND pre.customer_code = post.customer_code
        AND pre.product_code = post.product_code)

select *, (1-post_invoice_discount_pct) * net_invoice_sales as net_sales from sales_postinv_discount_cte;
        
# Method 2 using views

SELECT 
    *,
    (1 - post_invoice_discount_pct) * net_invoice_sales AS net_sales
FROM
    sales_postinv_discount
LIMIT 10000000;
    
    
/*
Create a table for gross sales. It should have the following columns,

1.	date
2.	fiscal_year
3.	customer_code
4.	customer
5.	market
6.	product_code
7.	product
8.	variant
9.	sold_quanity
10.	gross_price_per_item
11.	gross_price_total

*/
SELECT 
    fsm.date,
    fsm.fiscal_year,
    fsm.customer_code,
    dc.customer,
    dc.market,
    fsm.product_code,
    dp.product,
    dp.variant,
    fsm.sold_quantity,
    fgp.gross_price,
    (fgp.gross_price * fsm.sold_quantity) as gross_price_total
FROM
    fact_sales_monthly fsm
        JOIN
        
    dim_customer dc USING (customer_code)
        JOIN
    dim_product dp USING (product_code)
        JOIN
    fact_gross_price fgp ON fsm.product_code = fgp.product_code
        AND fsm.fiscal_year = fgp.fiscal_year
LIMIT 1000000000;


-- Retrieving Top 5 markets by net sales for FY 2021

SELECT 
    market, round(SUM(net_sales)/1000000,2) AS Net_Sales_Mlns
FROM
    net_sales
WHERE
    fiscal_year = 2021
GROUP BY market
ORDER BY Net_Sales_Mlns DESC
LIMIT 5;


-- Retrieving Top 5 customers by net sales for FY 2021

SELECT 
    dc.customer,
    ROUND(SUM(net_sales) / 1000000, 2) AS Net_Sales_Mlns
FROM
    net_sales ns
        JOIN
    dim_customer dc USING (customer_code)
WHERE
    fiscal_year = 2021 and dc.market = "india"
GROUP BY dc.customer
ORDER BY Net_Sales_Mlns DESC
LIMIT 5;


-- Retrieving Top 5 products by net sales for FY 2021


SELECT 
    product, round(SUM(net_sales)/1000000,2) AS Net_Sales_Mlns
FROM
    net_sales
WHERE
    fiscal_year = 2021
GROUP BY product
ORDER BY Net_Sales_Mlns DESC
LIMIT 5;


-- Net percent sales of every customer for FY 2021

with sales_cte as (
SELECT 
    dc.customer,
    ROUND(SUM(net_sales) / 1000000, 2) AS Net_Sales_Mlns
FROM
    net_sales ns
        JOIN
    dim_customer dc USING (customer_code)
WHERE
    fiscal_year = 2021
GROUP BY dc.customer
ORDER BY Net_Sales_Mlns DESC)

SELECT *,
Net_Sales_Mlns*100 /sum(Net_Sales_Mlns) OVER() AS net_sales_pct 
FROM sales_cte 
ORDER BY net_sales_pct DESC;


-- Net percent sales of every region for FY 2021

with sales_cte as (
SELECT 
    dc.customer, 
    dc.region,
    ROUND(SUM(net_sales) / 1000000, 2) AS Net_Sales_Mlns
FROM
    net_sales ns
        JOIN
    dim_customer dc USING (customer_code)
WHERE
    fiscal_year = 2021 
GROUP BY dc.customer, dc.region
ORDER BY Net_Sales_Mlns DESC)

select *, Net_Sales_Mlns*100/sum(Net_Sales_Mlns) over(partition by region) as Net_Regional_Sale from sales_cte;


/* 
Get Top n products of each division by net quantity sold
*/

with cte1 as(
SELECT 
    dp.division, 
    dp.product, 
    sum(fsm.sold_quantity) as total_sales
FROM
    dim_product dp
        JOIN
    fact_sales_monthly fsm USING (product_code)
    where fsm.fiscal_year = 2021
    group by dp.division, dp.product),
    
cte2 as(
select *, dense_rank() over (partition by division order by total_sales desc) as drnk from cte1)
select division, product, total_sales from cte2 where drnk <= 3;


/* 
Get Top n markets of each region by gross sales amount in FY 2021
*/


with cte1 as(
SELECT 
    dc.market,
    dc.region,
    SUM((fsm.sold_quantity * fgp.gross_price)) / 1000000 AS gross_price_mlns
FROM
    fact_sales_monthly fsm
        JOIN
    dim_customer dc USING (customer_code)
        JOIN
    fact_gross_price fgp ON fgp.product_code = fsm.product_code
        AND fgp.fiscal_year = fsm.fiscal_year
WHERE
    fsm.fiscal_year = 2021
GROUP BY dc.market , dc.region
ORDER BY region),
 
cte2 as (
select *, dense_rank() over(partition by region order by gross_price_mlns desc) as drnk from cte1)

select * from cte2 where drnk <=2;


/* 
Creating a helper table to determine the net forecasting error 
*/

	drop table if exists fact_act_est;

	CREATE TABLE fact_act_est (SELECT s.date AS date,
    s.fiscal_year AS fiscal_year,
    s.product_code AS product_code,
    s.customer_code AS customer_code,
    s.sold_quantity AS sold_quantity,
    f.forecast_quantity AS forecast_quantity FROM
    fact_sales_monthly s
        LEFT JOIN
    fact_forecast_monthly f USING (date , customer_code , product_code)) UNION (SELECT 
    f.date AS date,
    f.fiscal_year AS fiscal_year,
    f.product_code AS product_code,
    f.customer_code AS customer_code,
    s.sold_quantity AS sold_quantity,
    f.forecast_quantity AS forecast_quantity
FROM
    fact_forecast_monthly f
        LEFT JOIN
    fact_sales_monthly s USING (date , customer_code , product_code));




-- Trigger Testing 


SELECT 
    *
FROM
    fact_act_est;
    
SELECT 
    COUNT(*)
FROM
    fact_act_est
WHERE
    forecast_quantity IS NULL;

UPDATE fact_act_est 
SET 
    sold_quantity = 0
WHERE
    sold_quantity IS NULL;

UPDATE fact_act_est 
SET 
    forecast_quantity = 0
WHERE
    forecast_quantity IS NULL;
    
    
SET SQL_SAFE_UPDATES = 0;


SELECT 
    *
FROM
    fact_act_est;

insert into fact_sales_monthly(date, product_code, customer_code, sold_quantity) values ("2033-10-01", "Product", 123123, 69);

insert into fact_forecast_monthly(date, product_code, customer_code, forecast_quantity) values ("2033-10-01", "Product", 123123, 99);

SELECT 
    *
FROM
    fact_sales_monthly
WHERE
    product_code = 'Product';

SELECT 
    *
FROM
    fact_forecast_monthly
WHERE
    product_code = 'Product';

SELECT 
    *
FROM
    fact_act_est
WHERE
    product_code = 'Product'; 



-- Generating report on FOrecast Accuracy for FY 2021

with cte1 as (
SELECT 
    customer_code,
    SUM(sold_quantity) AS total_sold_qty,
    SUM(forecast_quantity) AS total_forecast_qty,
    SUM(forecast_quantity - sold_quantity) AS net_err,
    SUM(forecast_quantity - sold_quantity) * 100 / SUM(forecast_quantity) AS net_err_pct,
    SUM(ABS(forecast_quantity - sold_quantity)) AS abs_err,
    SUM(ABS(forecast_quantity - sold_quantity)) * 100 / SUM(forecast_quantity) AS abs_err_pct
FROM
    fact_act_est
WHERE
    fiscal_year = 2021
GROUP BY customer_code
ORDER BY abs_err_pct desc
)

SELECT 	cte1.customer_code,
		dc.customer, 
		dc.market,
        cte1.total_sold_qty,
        cte1.total_forecast_qty,
        cte1.net_err,
        cte1.net_err_pct,
        cte1.abs_err,
        cte1.abs_err_pct,
		IF(abs_err_pct > 100, 0, 100-abs_err_pct) AS forecast_accuracy 
FROM cte1
JOIN dim_customer dc
USING (customer_code)
ORDER BY forecast_accuracy DESC;