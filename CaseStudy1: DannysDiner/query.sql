-- What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(m.price) AS sum_price FROM sales s
JOIN  menu m
ON s.product_id=m.product_id
GROUP BY customer_id;


-- How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS visited
FROM sales
GROUP BY customer_id;


-- What was the first item from the menu purchased by each customer?
WITH orderRank AS (
  SELECT 
    customer_id,
    product_id,
    order_date,
    DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS rnk
  FROM sales
)
SELECT 
  o.customer_id,
  o.order_date,
  m.product_name
FROM orderRank o
JOIN menu m 
  ON o.product_id = m.product_id
WHERE o.rnk = 1
GROUP BY o.customer_id, o.order_date, m.product_name;


-- What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1 m.product_id, m.product_name, COUNT(s.product_id) most_ordered FROM sales s
JOIN menu m
ON s.product_id=m.product_id
GROUP BY m.product_id, m.product_name
ORDER BY most_ordered DESC;


-- Which item was the most popular for each customer?

WITH most_pop AS (
SELECT s.customer_id, m.product_name, COUNT(s.product_id) AS most_ordered,
DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS rank
FROM sales s
JOIN menu m
ON s.product_id=m.product_id
GROUP BY s.customer_id, m.product_name
)
SELECT customer_id,product_name,most_ordered FROM most_pop
WHERE rank=1;


-- Which item was purchased first by the customer after they became a member?

WITH afterMemb AS (
SELECT s.customer_id, s.order_date, m.product_name, mm.join_date, 
DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) rnk
FROM sales s
JOIN members mm
ON s.customer_id=mm.customer_id
JOIN menu m
ON s.product_id=m.product_id
WHERE s.order_date>=mm.join_date
)
SELECT * FROM afterMemb
WHERE rnk=1;


-- Which item was purchased just before the customer became a member?

WITH orderBeforeMemb AS (
SELECT s.customer_id, s.order_date, m.product_name, mm.join_date,
DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) rank
FROM sales s
JOIN menu m
ON s.product_id=m.product_id
JOIN members mm
ON s.customer_id=mm.customer_id
WHERE s.order_date < mm.join_date
)
SELECT * FROM orderBeforeMemb
where rank = 1;

-- What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(s.product_id) AS total_item, SUM(m.price) AS total_spend
FROM sales s
JOIN menu m
ON s.product_id=m.product_id
JOIN members mm
ON s.customer_id=mm.customer_id
WHERE s.order_date < mm.join_date
GROUP BY s.customer_id;


-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT s.customer_id,
SUM(CASE 
WHEN m.product_name='sushi' THEN m.price*20 
ELSE m.price*10 END) AS points
FROM sales s
JOIN menu m
ON s.product_id=m.product_id
GROUP BY s.customer_id;


-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH programDates AS(
SELECT customer_id, join_date, DATEADD(day, 6, join_date) AS valid_date, EOMONTH('01-01-2021') AS last_date 
FROM members
)
SELECT p.customer_id, SUM(CASE 
WHEN s.order_date BETWEEN p.join_date AND p.valid_date THEN m.price*20
WHEN m.product_name = 'sushi' THEN m.price*20
ELSE m.price*10 END) AS total_points
FROM sales s
JOIN programDates p
ON s.customer_id=p.customer_id
JOIN menu m
ON s.product_id=m.product_id
WHERE s.order_date <= last_date
GROUP BY p.customer_id;

-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N).

SELECT s.customer_id, s.order_date, m.product_name, m.price, 
CASE WHEN s.order_date>=mm.join_date THEN 'Y'
ELSE 'N' END AS membr
FROM sales s
JOIN menu m
ON s.product_id=m.product_id
LEFT JOIN members mm
ON s.customer_id=mm.customer_id


-- Rank All The Things (expects null ranking values for the records when customers are not yet members).

WITH customersData AS (
SELECT s.customer_id, s.order_date, m.product_name, m.price, 
CASE WHEN s.order_date>=mm.join_date THEN 'Y'
ELSE 'N' END AS membr
FROM sales s
JOIN menu m
ON s.product_id=m.product_id
LEFT JOIN members mm
ON s.customer_id=mm.customer_id
)
SELECT *, 
CASE WHEN membr = 'Y'
THEN DENSE_RANK() OVER(PARTITION BY customer_id, membr ORDER BY order_date)
END AS ranking
FROM customersData