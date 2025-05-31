-- Croma Sales Report
SELECT 
    s.date,
    s.product_code,
    p.product,
    p.variant,
    s.sold_quantity,
    g.gross_price,
    ROUND((s.sold_quantity * g.gross_price), 2) AS gross_price_total
FROM
    fact_sales_monthly s
        JOIN
    dim_product p ON s.product_code = p.product_code
        JOIN
    fact_gross_price g ON g.product_code = s.product_code
        AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
WHERE
    customer_code = 90002002
        AND GET_FISCAL_YEAR(date) = 2021
ORDER BY date ASC;


-- Croma yearly growth sales report
SELECT 
    g.fiscal_year,
    SUM(ROUND(s.sold_quantity * g.gross_price, 2)) AS gross_price_total
FROM
    fact_sales_monthly s
        JOIN
    fact_gross_price g ON s.product_code = g.product_code
        AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
WHERE
    customer_code = 90002002
GROUP BY g.fiscal_year
ORDER BY g.fiscal_year ASC;


--Top 5 market in fiscal year 2021
SELECT 
		market, ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
	FROM
		net_sales
	WHERE
		fiscal_year = 2021
	GROUP BY market
	ORDER BY net_sales_mln DESC
	LIMIT 5;


--Top 5 products in fiscal year 2021
SELECT 
		product,
		ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
	FROM
		net_sales
	WHERE
		fiscal_year = 2021
	GROUP BY product
	ORDER BY net_sales_mln DESC
	LIMIT 5;


--Top 5 customers in fiscal year 2021
SELECT 
		c.customer,
		ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
	FROM
		net_sales ns
			JOIN
		dim_customer c ON ns.customer_code = c.customer_code
	WHERE
		ns.fiscal_year = 2021
	GROUP BY c.customer
	ORDER BY net_sales_mln DESC
	LIMIT 5;


-- Net slaes % report
with cte1 as (SELECT
		c.customer,
		c.region,
		ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
	FROM
		net_sales ns
			JOIN
		dim_customer c ON ns.customer_code = c.customer_code
	WHERE
		ns.fiscal_year = 2021
	GROUP BY c.customer, c.region),
	cte2 as (select *, round(net_sales_mln * 100 / sum(net_sales_mln) over(partition by region), 2) as pct_share_region
	from cte1),
	cte3 as (select *,
		dense_rank() over(partition by region order by pct_share_region desc) as drnk
	from cte2)
	select *
	from cte3
	where drnk <= 5;

--Forecast accuracy comparison 2020 vs 2021
with cte20 as (SELECT 
		e.*, 
        dt.fiscal_year,
		sum(sold_quantity) as total_sold_quantity,
		sum(forecast_quantity) as total_forecast_quantity,
		sum(forecast_quantity - sold_quantity) as net_err,
		sum(abs(forecast_quantity - sold_quantity))  as abs_err,
		(sum(forecast_quantity - sold_quantity) * 100 / sum(forecast_quantity)) as net_err_pct,
		(sum(abs(forecast_quantity - sold_quantity)) *100 / sum(forecast_quantity)) as abs_err_pct_2020
	FROM fact_act_est e
		join 
	dim_date dt on dt.calendar_date = e.date
    where dt.fiscal_year = 2020
	group by customer_code),
cte21 as (SELECT 
		e.*, 
        dt.fiscal_year,
		sum(sold_quantity) as total_sold_quantity,
		sum(forecast_quantity) as total_forecast_quantity,
		sum(forecast_quantity - sold_quantity) as net_err,
		sum(abs(forecast_quantity - sold_quantity))  as abs_err,
		(sum(forecast_quantity - sold_quantity) * 100 / sum(forecast_quantity)) as net_err_pct,
		(sum(abs(forecast_quantity - sold_quantity)) *100 / sum(forecast_quantity)) as abs_err_pct_2021
	FROM fact_act_est e
		join 
	dim_date dt on dt.calendar_date = e.date
    where dt.fiscal_year = 2021
	group by customer_code) 
select c.customer_code, c.customer, c.market,
	if(abs_err_pct_2020 > 100, 0, round(100 - abs_err_pct_2020, 2)) as forecast_accuracy_2020,
    if(abs_err_pct_2021 > 100, 0, 100 - round(abs_err_pct_2021, 2)) as forecast_accuracy_2021
from cte20 c20
	join
dim_customer c on c.customer_code = c20.customer_code
	join
cte21 c21 on c21.customer_code = c20.customer_code
	and c21.product_code = c20.product_code 
order by forecast_accuracy_2021 desc;
