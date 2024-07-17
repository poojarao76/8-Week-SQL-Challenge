# 🍕 Case Study #2 - Pizza Runner

<p align="center">
  <img src="https://8weeksqlchallenge.com/images/case-study-designs/2.png" width="400" />
</p>


## 📚 Table of Contents

* Business Task
* Entity Relationship Diagram
* Data Cleaning and Transformation
* Solution:

    A. Pizza Metrics

    B. Runner and Customer Experience

    C. Ingredient Optimisation

    D. Pricing and Ratings

## Business Task


Danny was scrolling through his Instagram feed when something really caught his eye - “80s Retro Styling and Pizza Is The Future!”

Danny was sold on the idea, but he knew that pizza alone was not going to help him get seed funding to expand his new Pizza Empire - so he had one more genius idea to combine with it - he was going to Uberize it - and so Pizza Runner was launched!

Danny started by recruiting “runners” to deliver fresh pizza from Pizza Runner Headquarters (otherwise known as Danny’s house) and also maxed out his credit card to pay freelance developers to build a mobile app to accept orders from customers.

## Entity Relationship Diagram


![alt text](../assets/cs2/image.png)


## 🧼 Data Cleaning & Transformation

### 🔨 Table: customer_orders

* The exclusions and extras columns in customer_orders table will need to be cleaned up before using them in the queries
* In the exclusions and extras columns, there are blank spaces and null values.

    ```
    DROP TABLE IF EXISTS #customer_orders_temp;
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
    ```

    ![alt text](image-1.png)


### 🔨 Table: runner_orders

* The pickup_time, distance, duration and cancellation columns in runner_orders table will need to be cleaned up before using them in the queries
* In the pickup_time column, there are null values.
* In the distance column, there are null values. It contains unit - km. The 'km' must also be stripped.
* In the duration column, there are null values. The 'minutes', 'mins' 'minute' must be stripped.
* In the cancellation column, there are blank spaces and null values.

    ```
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
    ```

    ![alt text](image-2.png)


## Solution:

### A. Pizza Metrics

**1. How many pizzas were ordered?**

```console
SELECT COUNT(order_id) AS total_orders FROM #customer_orders_temp;
```

![alt text](image-3.png)

**2. How many unique customer orders were made?**

```console
SELECT COUNT(DISTINCT order_id) AS unique_customer_orders FROM #customer_orders_temp;
```

![alt text](image-4.png)

**3. How many successful orders were delivered by each runner?**

```console
SELECT runner_id, COUNT(order_id) AS successfull_orders
FROM #runner_orders_temp
WHERE cancellation IS NULL
GROUP BY runner_id;
```

![alt text](image-5.png)

**4. How many of each type of pizza was delivered?**

```console
SELECT c.pizza_id, pn.pizza_name, COUNT(c.order_id) AS total FROM #customer_orders_temp AS c
JOIN pizza_names AS pn
ON c.pizza_id=pn.pizza_id
WHERE C.order_id IN 
(SELECT order_id FROM #runner_orders_temp WHERE cancellation IS NULL)
GROUP BY c.pizza_id, pn.pizza_name;
```

![alt text](image-6.png)

**5. How many Vegetarian and Meatlovers were ordered by each customer?**

```console
SELECT c.customer_id, pn.pizza_name, COUNT(c.pizza_id) AS total_orders
FROM #customer_orders_temp c
JOIN pizza_names pn
ON c.pizza_id=pn.pizza_id
GROUP BY c.customer_id, pn.pizza_name
ORDER BY c.customer_id;
```

![alt text](image-7.png)

**6. What was the maximum number of pizzas delivered in a single order?**

```console
SELECT top 1 customer_id, order_id, COUNT(order_id) AS orders
FROM #customer_orders_temp
GROUP BY customer_id, order_id
ORDER BY orders DESC;
```

![alt text](image-8.png)

**7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?**

```console
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
```
![alt text](image-9.png)

**8. How many pizzas were delivered that had both exclusions and extras?**

```console
SELECT SUM(CASE WHEN exclusions IS NOT NULL AND extras IS NOT NULL THEN 1 ELSE 0 END) AS total 
FROM #customer_orders_temp c
JOIN #runner_orders_temp r
ON c.order_id=r.order_id
WHERE r.cancellation IS NULL;
```

![alt text](image-10.png)

**9. What was the total volume of pizzas ordered for each hour of the day?**

```console
SELECT DATEPART(HOUR, order_time) AS hr, COUNT(order_id) AS total_order FROM #customer_orders_temp
GROUP BY DATEPART(HOUR, order_time);
```
![alt text](image-11.png)

**10. What was the volume of orders for each day of the week?**

```console
SELECT DATENAME(WEEKDAY, order_time) AS DAY, COUNT(order_id) AS orders
FROM #customer_orders_temp
GROUP BY DATENAME(WEEKDAY, order_time);
```

![alt text](image-12.png)


### B. Runner and Customer Experience

**1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)**

```console
select DATEPART(week, registration_date) as regist_week, count(runner_id) as runner_count from runners
group by DATEPART(week, registration_date);
```

![alt text](image-13.png)

**2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?**

```console
SELECT ro.runner_id, 
AVG(CAST(DATEDIFF(MINUTE, co.order_time, ro.pickup_time) AS int)) AS avg_time
FROM runner_orders ro
JOIN customer_orders co
ON ro.order_id = co.order_id
WHERE ro.cancellation IS NULL OR ro.cancellation = ''
GROUP BY ro.runner_id;
```

![alt text](image-14.png)

**3. Is there any relationship between the number of pizzas and how long the order takes to prepare?**

```
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
```

![alt text](image-15.png)

**4. What was the average distance travelled for each customer?**

```console
WITH avgDist AS (
SELECT c.customer_id, ROUND(AVG(CAST(r.distance as float)),2) AS tot_dist
FROM #runner_orders_temp r
JOIN #customer_orders_temp c
ON r.order_id=c.order_id
WHERE (r.cancellation IS NULL)
GROUP BY c.customer_id)

SELECT *
FROM avgDist
```

![alt text](image-16.png)

**5. What was the difference between the longest and shortest delivery times for all orders?**

```console
SELECT MAX(CONVERT(int, duration))-MIN(CONVERT(int, duration)) AS "diff in duration" FROM #runner_orders_temp;
```

![alt text](image-17.png)

**6. What was the average speed for each runner for each delivery and do you notice any trend for these values?**

```
SELECT r.runner_id, r.order_id, r.distance, r.duration, ROUND((CONVERT(float, r.distance)/CONVERT(float, r.duration) * 60), 2) AS [avg delivery time]
FROM #runner_orders_temp r
JOIN #customer_orders_temp c
ON r.order_id=C.order_id
WHERE r.cancellation IS NULL
GROUP BY r.order_id, r.runner_id, r.distance, r.duration
```

![alt text](image-18.png)

**7. What is the successful delivery percentage for each runner?**

```
SELECT runner_id, COUNT(order_id) AS total_orders, COUNT(distance) AS delivered, 100*(COUNT(distance))/COUNT(order_id) AS successful_pct
FROM #runner_orders_temp
GROUP BY runner_id
```

![alt text](image-19.png)