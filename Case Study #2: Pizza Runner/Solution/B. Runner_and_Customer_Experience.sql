--Data cleaning

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


DROP TABLE IF EXISTS #runner_orders_temp;
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
	WHEN duration LIKE '%mins' THEN TRIM('mins' FROM duration)
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

---- Queries


select * from runners
select * from runner_orders
select * from customer_orders
select * from pizza_names
select * from pizza_recipes
select * from pizza_toppings

--1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select DATEPART(week, registration_date) as regist_week, count(runner_id) as runner_count from runners
group by DATEPART(week, registration_date);

--2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT ro.runner_id, 
AVG(CAST(DATEDIFF(MINUTE, co.order_time, ro.pickup_time) AS int)) AS avg_time
FROM runner_orders ro
JOIN customer_orders co
ON ro.order_id = co.order_id
WHERE ro.cancellation IS NULL OR ro.cancellation = ''
GROUP BY ro.runner_id;

--3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

WITH pizzaPrepTime AS (
SELECT c.order_id, c.order_time, r.pickup_time, DATEDIFF(MINUTE, c.order_time, r.pickup_time) AS prep_time, COUNT(c.pizza_id) AS pizza_count 
FROM #customer_orders_temp c
JOIN #runner_orders_temp r
ON c.order_id=r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.order_id, c.order_time, r.pickup_time, DATEDIFF(MINUTE, c.order_time, r.pickup_time))

SELECT pizza_count, AVG(prep_time) as total_time
FROM pizzaPrepTime
GROUP BY pizza_count;

--4. What was the average distance travelled for each customer?

WITH avgDist AS (
SELECT c.customer_id, ROUND(AVG(CAST(r.distance as float)),2) AS tot_dist
FROM #runner_orders_temp r
JOIN #customer_orders_temp c
ON r.order_id=c.order_id
WHERE (r.cancellation IS NULL)
GROUP BY c.customer_id)

SELECT *
FROM avgDist

--5. What was the difference between the longest and shortest delivery times for all orders?

SELECT MAX(CONVERT(int, duration))-MIN(CONVERT(int, duration)) AS "diff in duration" FROM #runner_orders_temp;

--6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT r.runner_id, r.order_id, r.distance, r.duration, ROUND((CONVERT(float, r.distance)/CONVERT(float, r.duration) * 60), 2) AS [avg delivery time]
FROM #runner_orders_temp r
JOIN #customer_orders_temp c
ON r.order_id=C.order_id
WHERE r.cancellation IS NULL
GROUP BY r.order_id, r.runner_id, r.distance, r.duration

--7. What is the successful delivery percentage for each runner?

SELECT runner_id, COUNT(order_id) AS total_orders, COUNT(distance) AS delivered, 100*(COUNT(distance))/COUNT(order_id) AS successful_pct
FROM #runner_orders_temp
GROUP BY runner_id