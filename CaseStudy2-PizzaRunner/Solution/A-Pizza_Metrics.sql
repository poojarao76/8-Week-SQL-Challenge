-- Data cleaning

-- Create a new temporaray table: #customer_orders_temp

SELECT order_id,customer_id,pizza_id,
CASE 
	WHEN exclusions IS NULL OR exclusions LIKE 'null' OR exclusions = '' THEN NULL
	ELSE exclusions END AS exclusions,
CASE 
	WHEN extras IS NULL OR extras LIKE 'null' OR extras = '' THEN NULL
	ELSE extras END AS extras,
order_time
INTO #customer_orders_temp
FROM customer_orders;

SELECT * FROM #customer_orders_temp;


-- Create a new temporaray table: #runner_orders_temp

select * from runner_orders;

SELECT order_id, runner_id,
CASE
	WHEN pickup_time='null' THEN NULL
	ELSE pickup_time 
	END AS pickup_time,
CASE 
	WHEN distance='null' THEN NULL
	WHEN distance LIKE '%km'THEN TRIM('km' FROM distance)
	ELSE distance
	END AS distance,
CASE 
	WHEN duration = 'null' THEN NULL
	WHEN duration LIKE '% mins' THEN TRIM('mins' FROM duration)
	WHEN duration LIKE '%minute' THEN TRIM('minute' FROM duration)
	WHEN duration LIKE '%minutes' THEN TRIM('minutes' FROM duration)
	ELSE duration
	END AS duration,
CASE
	WHEN cancellation = 'null' OR cancellation = '' THEN NULL
	ELSE cancellation
	END AS cancellation
INTO #runner_orders_temp
FROM runner_orders;

SELECT * FROM #runner_orders_temp;


-- Queries

--1. How many pizzas were ordered?
SELECT COUNT(order_id) AS total_orders FROM #customer_orders_temp;


--How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_customer_orders FROM #customer_orders_temp;


--How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(order_id) AS successfull_orders
FROM #runner_orders_temp
WHERE cancellation IS NULL
GROUP BY runner_id;


--How many of each type of pizza was delivered?
SELECT c.pizza_id, pn.pizza_name, COUNT(c.order_id) AS total FROM #customer_orders_temp AS c
JOIN pizza_names AS pn
ON c.pizza_id=pn.pizza_id
WHERE C.order_id IN 
(SELECT order_id FROM #runner_orders_temp WHERE cancellation IS NULL)
GROUP BY c.pizza_id, pn.pizza_name;


--How many Vegetarian and Meatlovers were ordered by each customer?
SELECT c.customer_id, pn.pizza_name, COUNT(c.pizza_id) AS total_orders
FROM #customer_orders_temp c
JOIN pizza_names pn
ON c.pizza_id=pn.pizza_id
GROUP BY c.customer_id, pn.pizza_name
ORDER BY c.customer_id;


--What was the maximum number of pizzas delivered in a single order?
SELECT top 1 customer_id, order_id, COUNT(order_id) AS orders
FROM #customer_orders_temp
GROUP BY customer_id, order_id
ORDER BY orders DESC;


--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT c.customer_id, 
SUM(CASE
	WHEN (c.exclusions IS NOT NULL or c.extras IS NOT NULL) THEN 1 
	ELSE 0 END) AS atleat_1_change,
SUM(CASE
	WHEN (c.exclusions IS NULL AND c.extras IS NULL) THEN 1
	ELSE 0 END) AS no_change
FROM #customer_orders_temp c
JOIN #runner_orders_temp r
ON c.order_id = r.order_id
WHERE R.cancellation IS NULL
GROUP BY C.customer_id;


--How many pizzas were delivered that had both exclusions and extras?
SELECT SUM(CASE WHEN exclusions IS NOT NULL AND extras IS NOT NULL THEN 1 ELSE 0 END) AS total 
FROM #customer_orders_temp c
JOIN #runner_orders_temp r
ON c.order_id=r.order_id
WHERE r.cancellation IS NULL;


--What was the total volume of pizzas ordered for each hour of the day?
SELECT DATEPART(HOUR, order_time) AS hr, COUNT(order_id) AS total_order FROM #customer_orders_temp
GROUP BY DATEPART(HOUR, order_time);


--What was the volume of orders for each day of the week?
SELECT DATENAME(WEEKDAY, order_time) AS DAY, COUNT(order_id) AS orders
FROM #customer_orders_temp
GROUP BY DATENAME(WEEKDAY, order_time);