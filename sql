1. Find the latest record for each customer
Hard
Give the candidate this table: customer_transactions
customer_id	txn_id	amount	updated_at
101	T1	500	2026-10-25 10:00
101	T2	800	2026-10-26 11:00
102	T3	300	2026-10-24 09:00
102	T4	400	2026-10-26 12:00
103	T5	900	2026-10-25 15:00

Ask: Write a SQL query to return the latest transaction record for each customer, including all columns.

Expected output:
customer_id	txn_id	amount
101	T2	800
102	T4	400
103	T5	900

Expected solution:

WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY updated_at DESC, txn_id DESC
           ) AS rn
    FROM customer_transactions
)
SELECT customer_id, txn_id, amount, updated_at
FROM ranked
WHERE rn = 1;



Follow-up: What is the difference between ROW_NUMBER(), RANK(), and DENSE_RANK()? What happens if two records have the same timestamp?
2. Find employees earning more than their department's average
Hard
Table: employees
emp_id	emp_name	department	salary
1	Arun	IT	80000
2	Banu	IT	60000
3	Charan	IT	100000
4	Divya	HR	50000
5	Ezhil	HR	70000
6	Farah	HR	60000

Ask: Return employees whose salary is greater than their department's average salary.

Expected output:
emp_id	emp_name	department	salary
1	Arun	IT	80000
3	Charan	IT	100000
5	Ezhil	HR	70000

Expected solution:

SELECT emp_id, emp_name, department, salary
FROM (
    SELECT e.*,
           AVG(salary) OVER (
               PARTITION BY department
           ) AS avg_salary
    FROM employees e
) x
WHERE salary > avg_salary;



Follow-up: Solve the same problem using GROUP BY and a join. Which approach would you choose, and why?
3. Find missing transaction dates
Very hard
Table: daily_transactions
customer_id	txn_date	amount
101	2026-10-01	100
101	2026-10-02	200
101	2026-10-05	300
102	2026-10-01	150
102	2026-10-03	250

Ask: Find all missing dates for each customer between their first and last transaction dates.

Expected output:
customer_id	missing_date
101	2026-10-03
101	2026-10-04
102	2026-10-02

Expected solution for databases supporting recursive CTEs, such as PostgreSQL:

WITH RECURSIVE date_ranges AS (
    SELECT customer_id,
           MIN(CAST(txn_date AS DATE)) AS start_date,
           MAX(CAST(txn_date AS DATE)) AS end_date
    FROM daily_transactions
    GROUP BY customer_id
),
calendar AS (
    SELECT customer_id, start_date AS missing_date, end_date
    FROM date_ranges

    UNION ALL

    SELECT customer_id,
           missing_date + INTERVAL '1 day',
           end_date
    FROM calendar
    WHERE missing_date < end_date
)
SELECT c.customer_id, c.missing_date
FROM calendar c
WHERE NOT EXISTS (
    SELECT 1
    FROM daily_transactions t
    WHERE t.customer_id = c.customer_id
      AND CAST(t.txn_date AS DATE) = c.missing_date
)
ORDER BY c.customer_id, c.missing_date;



Follow-up: How would you solve this without a recursive CTE? A strong candidate might use a calendar table, a date dimension, or a database-specific date-generation function.

Note: Date arithmetic differs across SQL engines. The above syntax is PostgreSQL-style; the candidate should adapt it to the target platform.
4. Detect duplicate business keys and preserve the correct records
Very hard
Table: customer_master
customer_id	customer_name	city	effective_date
101	Ravi	Chennai	2026-01-01
101	Ravi	Bengaluru	2026-06-01
102	Kumar	Mumbai	2026-03-01
103	Priya	Chennai	2026-02-01
103	Priya	Pune	2026-02-01

Ask: Return exactly one current record per customer, selecting the latest effective_date.

Expected output:
customer_id	customer_name	city
101	Ravi	Bengaluru
102	Kumar	Mumbai
103	Priya	Requires a tie-breaker

Expected solution:

WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY effective_date DESC
           ) AS rn
    FROM customer_master
)
SELECT customer_id, customer_name, city, effective_date
FROM ranked
WHERE rn = 1;



Important interview point: Customer 103 has two records with the same effective date. The query returns one, but it cannot guarantee which city is selected. A senior candidate should identify this ambiguity and ask for a business rule or a deterministic tie-breaker, such as a source sequence or record ID.

Follow-up: How would you find all customer IDs that have duplicate records with the same effective date?
5. Calculate running totals and compare consecutive transactions
Hard
Table: transactions
customer_id	txn_date	txn_id	amount
101	2026-10-01	T1	100
101	2026-10-02	T2	200
101	2026-10-03	T3	150
102	2026-10-01	T4	300
102	2026-10-02	T5	100

Ask: Write SQL to calculate:
- Running total per customer.
- Previous transaction amount.
- Difference between current and previous transaction amount.
Expected output:
customer_id	txn_id	amount	running_total	previous_amount	difference
101	T1	100	100	NULL	NULL
101	T2	200	300	100	100
101	T3	150	450	200	-50
102	T4	300	300	NULL	NULL
102	T5	100	400	300	-200

Expected solution:

SELECT
    customer_id,
    txn_id,
    txn_date,
    amount,
    SUM(amount) OVER (
        PARTITION BY customer_id
        ORDER BY txn_date, txn_id
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS running_total,
    LAG(amount) OVER (
        PARTITION BY customer_id
        ORDER BY txn_date, txn_id
    ) AS previous_amount,
    amount - LAG(amount) OVER (
        PARTITION BY customer_id
        ORDER BY txn_date, txn_id
    ) AS difference
FROM transactions
ORDER BY customer_id, txn_date, txn_id;



Follow-up: Why explicitly specify ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW instead of relying on the default window frame?

Expected: The explicit frame ensures row-by-row running-total behavior. Default frames can treat equal ordering values as peers, depending on the SQL engine and function.

Recommended 30-minute SQL interview plan
Time	Question	Main skill tested
0–5 min	Latest record per customer	Window functions
5–10 min	Above-average salary	Aggregation and windows
10–17 min	Missing dates	CTEs and date logic
17–23 min	Duplicate business keys	Data quality and deterministic results
23–30 min	Running totals	Advanced analytical SQL

My recommendation: Ask the candidate to write Questions 1, 4, and 5 live, then use Questions 2 and 3 as follow-ups if time permits. For a 19-year senior engineer, assess correctness, edge cases, NULL handling, tie-breaking, and performance—not just whether the SQL runs.
