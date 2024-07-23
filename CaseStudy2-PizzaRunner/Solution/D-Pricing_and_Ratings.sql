-- Data Cleaning

-- 1. Create a new temporaray table: #customer_orders_temp

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

-- Add an identity column record_id to #customer_orders_temp to select each ordered pizza more easily

ALTER TABLE #customer_orders_temp
ADD record_id INT IDENTITY(1,1);

SELECT *
FROM #customer_orders_temp;



-- 2. Create a new temporaray table: #runner_orders_temp
	
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
SELECT * FROM #customer_orders_temp;
SELECT * FROM pizza_names;

-- 3. Create a new temporaray table: #extrasBreak 

SELECT 
  c.record_id,
  TRIM(e.value) AS extra_id
INTO #extrasBreak 
FROM #customer_orders_temp c
  CROSS APPLY STRING_SPLIT(extras, ',') AS e;

SELECT *
FROM #extrasBreak;

-- Queries

-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT SUM(CASE WHEN p.pizza_name LIKE 'Meatlovers' THEN 12 ELSE 10 END) AS money_earned
FROM #customer_orders_temp c
JOIN #runner_orders_temp ro
ON c.order_id=ro.order_id
JOIN pizza_names p
ON p.pizza_id=c.pizza_id
WHERE ro.cancellation IS NULL;


--What if there was an additional $1 charge for any pizza extras?
--Add cheese is $1 extra

DECLARE @basecost INT
SET @basecost = 138 	-- @basecost = result of the previous question

SELECT 
  @basecost + SUM(CASE WHEN p.topping_name = 'Cheese' THEN 2
		  ELSE 1 END) updated_money
FROM #extrasBreak e
JOIN pizza_toppings p
  ON e.extra_id = p.topping_id;


--The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset
-- generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.


DROP TABLE IF EXISTS ratings
CREATE TABLE ratings (
  order_id INT,
  rating INT);
INSERT INTO ratings (order_id, rating)
VALUES 
  (1,3),
  (2,5),
  (3,3),
  (4,1),
  (5,5),
  (7,3),
  (8,4),
  (10,3);

 SELECT *
 FROM ratings;


--Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--customer_id
--order_id
--runner_id
--rating
--order_time
--pickup_time
--Time between order and pickup
--Delivery duration
--Average speed
--Total number of pizzas


SELECT 
  c.customer_id,
  c.order_id,
  r.runner_id,
  c.order_time,
  r.pickup_time,
  DATEDIFF(MINUTE, c.order_time, r.pickup_time) AS mins_difference,
  r.duration,
  ROUND(AVG(convert(float,r.distance)/convert(float,r.duration*60)), 1) AS avg_speed,
  COUNT(c.order_id) AS pizza_count
FROM #customer_orders_temp c
JOIN #runner_orders_temp r 
  ON r.order_id = c.order_id
GROUP BY 
  c.customer_id,
  c.order_id,
  r.runner_id,
  c.order_time,
  r.pickup_time, 
  r.duration;


--If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza 
--Runner have left over after these deliveries?

DECLARE @basecost INT
SET @basecost = 138

SELECT 
  @basecost AS revenue,
  SUM(convert(float,distance))*0.3 AS runner_paid,
  @basecost - SUM(convert(float,distance))*0.3 AS money_left
FROM #runner_orders_temp;

-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new
--Supreme pizza with all the toppings was added to the Pizza Runner menu?

INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (3, 'Supreme');

ALTER TABLE pizza_recipes
ALTER COLUMN toppings VARCHAR(50);

INSERT INTO pizza_recipes (pizza_id, toppings)
VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');

SELECT * FROM pizza_recipes;