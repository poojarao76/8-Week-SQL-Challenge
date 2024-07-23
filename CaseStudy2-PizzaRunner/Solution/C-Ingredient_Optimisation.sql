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

-- 2. Create a new temporaray table: #extrasBreak 

SELECT 
  c.record_id,
  TRIM(e.value) AS extra_id
INTO #extrasBreak 
FROM #customer_orders_temp c
  CROSS APPLY STRING_SPLIT(extras, ',') AS e;

SELECT *
FROM #extrasBreak;

-- 3. Create a new temporaray table: #exclusionsBreak

SELECT 
  c.record_id,
  TRIM(e.value) AS exclusion_id
INTO #exclusionsBreak 
FROM #customer_orders_temp c
  CROSS APPLY STRING_SPLIT(exclusions, ',') AS e;

SELECT *
FROM #exclusionsBreak;


-- 4. Create a new temporaray table: #pizza_toppings_split

CREATE TABLE #pizza_toppings_split (
    pizza_id INT,
    pizza_name NVARCHAR(50),
    topping_id INT,
    topping_name NVARCHAR(50)
);


INSERT INTO #pizza_toppings_split (pizza_id, pizza_name, topping_id, topping_name)
SELECT pn.pizza_id,
    pn.pizza_name,
    CAST(s.value AS int) AS topping_id,
    pt.topping_name
FROM pizza_recipes pr
JOIN pizza_names pn
ON pr.pizza_id=pn.pizza_id
CROSS APPLY
	string_split(pr.toppings, ',') AS s
JOIN pizza_toppings pt
ON CAST(s.value AS int)=pt.topping_id;


SELECT * FROM #pizza_toppings_split;



--- Queries

-- What are the standard ingredients for each pizza?

SELECT * FROM pizza_toppings
SELECT * FROM pizza_names
SELECT * FROM pizza_recipes


SELECT pizza_name, STRING_AGG(topping_name, ',') AS 'standard ingredients'
FROM #pizza_toppings_split
GROUP BY pizza_name;


--What was the most commonly added extra?

SELECT * FROM #extrasBreak
SELECT * FROM #exclusionsBreak
SELECT * FROM #pizza_toppings_split


SELECT 
  p.topping_name,
  COUNT(*) AS extra_count
FROM #extrasBreak e
JOIN pizza_toppings p
  ON e.extra_id = p.topping_id
GROUP BY p.topping_name
ORDER BY COUNT(*) DESC;


--What was the most common exclusion?

SELECT pt.topping_name, COUNT(*) AS exclusion_count
FROM #exclusionsBreak eb
JOIN #pizza_toppings_split pt
ON eb.exclusion_id=pt.topping_id
GROUP BY pt.topping_name
ORDER BY COUNT(*) DESC;

--Generate an order item for each record in the customers_orders table in the format of one of the following:
--Meat Lovers
--Meat Lovers - Exclude Beef
--Meat Lovers - Extra Bacon
--Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH cteExtras AS (
  SELECT 
    e.record_id,
    'Extra ' + STRING_AGG(t.topping_name, ', ') AS record_options
  FROM #extrasBreak e
  JOIN pizza_toppings t
    ON e.extra_id = t.topping_id
  GROUP BY e.record_id
), 
cteExclusions AS (
  SELECT 
    e.record_id,
    'Exclusion ' + STRING_AGG(t.topping_name, ', ') AS record_options
  FROM #exclusionsBreak e
  JOIN pizza_toppings t
    ON e.exclusion_id = t.topping_id
  GROUP BY e.record_id
), 
cteUnion AS (
  SELECT * FROM cteExtras
  UNION
  SELECT * FROM cteExclusions
)

SELECT 
  c.record_id,
  c.order_id,
  c.customer_id,
  c.pizza_id,
  c.order_time,
  CONCAT_WS(' - ', p.pizza_name, STRING_AGG(u.record_options, ' - ')) AS pizza_info
FROM #customer_orders_temp c
LEFT JOIN cteUnion u
  ON c.record_id = u.record_id
JOIN pizza_names p
  ON c.pizza_id = p.pizza_id
GROUP BY
  c.record_id, 
  c.order_id,
  c.customer_id,
  c.pizza_id,
  c.order_time,
  p.pizza_name
ORDER BY record_id;



--Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH ingredients AS (
  SELECT 
    c.*,
    p.pizza_name,

    -- Add '2x' in front of topping_names if their topping_id appear in the #extrasBreak table
    CASE WHEN t.topping_id IN (
          SELECT extra_id 
          FROM #extrasBreak e 
          WHERE e.record_id = c.record_id)
      THEN '2x' + t.topping_name
      ELSE t.topping_name
    END AS topping

  FROM #customer_orders_temp c
  JOIN #pizza_toppings_split t
    ON t.pizza_id = c.pizza_id
  JOIN pizza_names p
    ON p.pizza_id = c.pizza_id

  -- Exclude toppings if their topping_id appear in the #exclusionBreak table
  WHERE t.topping_id NOT IN (
      SELECT exclusion_id 
      FROM #exclusionsBreak e 
      WHERE c.record_id = e.record_id)
)

SELECT 
  record_id,
  order_id,
  customer_id,
  pizza_id,
  order_time,
  CONCAT(pizza_name + ': ', STRING_AGG(topping, ', ')) AS ingredients_list
FROM ingredients
GROUP BY 
  record_id, 
  record_id,
  order_id,
  customer_id,
  pizza_id,
  order_time,
  pizza_name
ORDER BY record_id;


--What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

WITH frequentIngredients AS (
  SELECT 
    c.record_id,
    t.topping_name,
    CASE
      -- if extra ingredient, add 2
      WHEN t.topping_id IN (
          SELECT extra_id 
          FROM #extrasBreak e
          WHERE e.record_id = c.record_id) 
      THEN 2
      -- if excluded ingredient, add 0
      WHEN t.topping_id IN (
          SELECT exclusion_id 
          FROM #exclusionsBreak e 
          WHERE c.record_id = e.record_id)
      THEN 0
      -- no extras, no exclusions, add 1
      ELSE 1
    END AS times_used
  FROM #customer_orders_temp c
  JOIN #pizza_toppings_split t
    ON t.pizza_id = c.pizza_id
  JOIN pizza_names p
    ON p.pizza_id = c.pizza_id
)

SELECT 
  topping_name,
  SUM(times_used) AS times_used 
FROM frequentIngredients
GROUP BY topping_name
ORDER BY times_used DESC;