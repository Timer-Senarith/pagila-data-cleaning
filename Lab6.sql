-- ALY6420 Lab 5: Cleaning and Transforming Data
-- Timer Senarith
-- Save as: Lab5_Senarith_Timer.sql


-- Q1
-- Assign each film a price tier.

SELECT
    film_id,
    title,
    rental_rate,
    CASE
        WHEN rental_rate < 1.00 THEN 'Budget'
        WHEN rental_rate >= 1.00 AND rental_rate < 3.00 THEN 'Standard'
        WHEN rental_rate >= 3.00 THEN 'Premium'
    END AS price_tier
FROM film
ORDER BY rental_rate ASC;

-- For rental_rate = 0.99:
-- 1. 0.99 < 1.00 is TRUE, so the result is 'Budget'.
-- 2. 0.99 >= 1.00 AND 0.99 < 3.00 would be FALSE:
--    the first comparison is false and the second is true.
-- 3. 0.99 >= 3.00 would be FALSE.
-- CASE stops at the first true condition, so conditions 2 and 3
-- are not actually evaluated.

-- Checking query: count the films in each tier.

SELECT
    CASE
        WHEN rental_rate < 1.00 THEN 'Budget'
        WHEN rental_rate >= 1.00 AND rental_rate < 3.00 THEN 'Standard'
        WHEN rental_rate >= 3.00 THEN 'Premium'
    END AS price_tier,
    COUNT(*) AS film_count
FROM film
GROUP BY price_tier
ORDER BY MIN(rental_rate);

-- Film counts: Budget = ___; Standard = ___; Premium = ___.
-- Fill these in using the checking query above.


-- Q2
-- Calculate conditional counts and the average rate for R-rated films.

SELECT
    COUNT(*) AS total_films,
    COUNT(CASE WHEN rating = 'G' THEN 1 END) AS g_rated,
    COUNT(CASE WHEN rating IN ('PG', 'PG-13') THEN 1 END)
        AS pg_and_pg13,
    AVG(CASE WHEN rating = 'R' THEN rental_rate END)
        AS r_rated_avg_rate
FROM film;

-- When the condition is false, CASE WHEN ... THEN 1 END returns NULL.
-- COUNT ignores NULL, so only matching films are counted.
-- With ELSE 0, a false condition returns 0. COUNT counts zero because
-- it is not NULL, so nonmatching films would also be counted.
-- AVG ignores NULL too, so only R-rated rental rates enter the average.

-- Checking query: confirm the two counts add up to fewer than all films.

SELECT
    COUNT(CASE WHEN rating = 'G' THEN 1 END)
        + COUNT(CASE WHEN rating IN ('PG', 'PG-13') THEN 1 END)
        AS combined_count,
    COUNT(*) AS total_films,
    (
        COUNT(CASE WHEN rating = 'G' THEN 1 END)
        + COUNT(CASE WHEN rating IN ('PG', 'PG-13') THEN 1 END)
    ) < COUNT(*) AS fewer_than_total
FROM film;

-- Confirmation: fewer_than_total = ___.
-- The remaining films are rated R or NC-17.


-- Q3
-- Part A: use an alternative label when email is NULL.

SELECT
    customer_id,
    first_name,
    last_name,
    COALESCE(email, 'no email on file') AS contact
FROM customer
ORDER BY customer_id;

-- Checking query: count customers with a NULL email.

SELECT
    COUNT(*) AS null_email_count
FROM customer
WHERE email IS NULL;

-- Customers with a NULL email = ___.


-- Part B: protect the division from a zero rental rate.

SELECT
    film_id,
    title,
    replacement_cost,
    rental_rate,
    replacement_cost / NULLIF(rental_rate, 0.00) AS cost_rate_ratio
FROM film
ORDER BY film_id;

-- NULLIF(rental_rate, 0.00) returns NULL when rental_rate is 0.00.
-- Otherwise, it returns the original rental_rate.
-- Dividing a number by NULL returns NULL.
-- This leaves the ratio unknown instead of causing a division-by-zero
-- error that would stop the query.


-- Q4
-- Cap the duration at 7 and floor it at 3.

SELECT
    film_id,
    title,
    rental_duration,
    LEAST(rental_duration, 7) AS capped_duration,
    GREATEST(rental_duration, 3) AS floored_duration
FROM film
ORDER BY rental_duration ASC, film_id ASC;

-- GREATEST(rental_duration, 3) compares the duration of one film with 3,
-- returning 3 if its duration is lower and its own duration otherwise.
-- MAX(rental_duration) instead returns the highest duration across
-- all film rows.
-- If all existing durations fall between 3 and 7, these derived columns
-- will match the original values because no adjustment is needed.


-- Q5
-- Part A: standardize customer names.

SELECT
    customer_id,
    INITCAP(TRIM(last_name)) || ', '
        || INITCAP(TRIM(first_name)) AS display_name,
    LEFT(first_name, 1) || '.' AS first_initial,
    LENGTH(first_name || ' ' || last_name) AS name_length
FROM customer
ORDER BY display_name ASC;

-- Each name is trimmed and converted to initial capitals.
-- name_length deliberately uses the original, untrimmed names
-- with one space between them.


-- Part B: cast rental_rate to text and integer.

SELECT
    film_id,
    title,
    rental_rate::text AS rate_text,
    CAST(rental_rate AS integer) AS rate_truncated
FROM film
ORDER BY film_id;

-- I would prefer CAST when writing queries for a project that uses
-- multiple database systems because CAST is standard SQL syntax,
-- while :: is PostgreSQL-specific syntax.
-- Although the assignment names the column rate_truncated,
-- casting PostgreSQL numeric values to integer rounds them:
-- for example, 4.99 becomes 5.


-- Q6
-- Part A: summarize payments by month.

SELECT
    DATE_TRUNC('month', payment_date) AS payment_month,
    COUNT(*) AS payment_count,
    SUM(amount) AS total_revenue
FROM payment
GROUP BY DATE_TRUNC('month', payment_date)
ORDER BY payment_month ASC;

-- Checking query: identify the month with the highest revenue.
-- DENSE_RANK includes all tied months if there is a tie.

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', payment_date) AS payment_month,
        SUM(amount) AS total_revenue
    FROM payment
    GROUP BY DATE_TRUNC('month', payment_date)
),
ranked_months AS (
    SELECT
        payment_month,
        total_revenue,
        DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
    FROM monthly_revenue
)
SELECT
    payment_month,
    total_revenue
FROM ranked_months
WHERE revenue_rank = 1
ORDER BY payment_month;

-- Month with the highest total revenue = ___.


-- Part B: calculate the duration and starting weekday of completed rentals.

SELECT
    rental_id,
    rental_date,
    return_date,
    AGE(return_date, rental_date) AS rental_duration,
    EXTRACT(DOW FROM rental_date) AS rental_dow
FROM rental
WHERE return_date IS NOT NULL
ORDER BY rental_id;

-- Second query: count completed rentals by starting weekday.

SELECT
    EXTRACT(DOW FROM rental_date) AS rental_dow,
    COUNT(*) AS rental_count
FROM rental
WHERE return_date IS NOT NULL
GROUP BY EXTRACT(DOW FROM rental_date)
ORDER BY rental_count DESC, rental_dow ASC;

-- Most common rental_dow = ___; number of completed rentals = ___.
-- Weekday key:
-- 0 = Sunday, 1 = Monday, 2 = Tuesday, 3 = Wednesday,
-- 4 = Thursday, 5 = Friday, 6 = Saturday.

-- WHERE removes unfinished rentals from the result before the SELECT
-- expressions are logically calculated, so the output contains only
-- completed rentals with a return date available for AGE.
-- Without that filter, unfinished rentals would appear with NULL
-- durations; AGE with a NULL argument returns NULL rather than an error.

-- Q7

-- Error 1: Incorrect conditional counting
-- The incorrect expression is:
-- COUNT(CASE WHEN amount > 5.00 THEN 1
--            WHEN amount <= 5.00 THEN 0 END)
--
-- COUNT counts every non-NULL value, including 0. Therefore, this
-- expression counts payments both above and at or below $5.00,
-- rather than counting only high-value payments.
-- If amount is NULL, neither condition matches and that row is excluded.
-- The correction returns 1 for payments above $5.00 and NULL otherwise,
-- allowing COUNT to count only matching payments.


-- Error 2: Incorrect COALESCE argument order
-- The incorrect expression is:
-- COALESCE('no date recorded', payment_date::text)
--
-- COALESCE returns its first non-NULL argument. Because the literal
-- 'no date recorded' is never NULL, it would always be selected,
-- even when a payment date exists.
-- The date label should come first and the fallback text second.
-- Since this query summarizes months, the corrected label uses the
-- grouped month rather than an individual payment's date.


-- Error 3: Grouping by month number loses the year
-- The incorrect expression is:
-- EXTRACT(MONTH FROM payment_date)
-- This affects both the SELECT and GROUP BY clauses.
--
-- EXTRACT(MONTH) returns only a number from 1 to 12, discarding the year.
-- For example, May 2005 and May 2006 would both belong to group 5.
-- Their payment counts and revenue-related calculations would therefore
-- be combined instead of reported as separate monthly results.
--
-- According to the assignment, Pagila's payments span May-August 2005
-- and February 2006. None of those calendar months occurs in both years,
-- so grouping by month number does not visibly merge different years
-- in this dataset. However, it remains incorrect for datasets containing
-- overlapping calendar months across years.
-- Ordering by month number also places February 2006 before May 2005,
-- rather than presenting the results chronologically.
--
-- DATE_TRUNC('month', payment_date) preserves both year and month,
-- keeping each calendar month separate and correctly ordered.


-- Additional issue in the supplied query:
-- The original safe_date expression references payment_date directly,
-- although it is neither grouped nor aggregated. PostgreSQL can reject
-- this with a GROUP BY error, contrary to the brief's claim that it runs.
-- The corrected query groups first, then creates the label from that
-- grouped month, resolving this issue as well.


WITH monthly_payments AS (
    SELECT
        DATE_TRUNC('month', payment_date) AS pay_month,
        COUNT(*) AS total_payments,
        COUNT(
            CASE
                WHEN amount > 5.00 THEN 1
            END
        ) AS high_value_count
    FROM payment
    GROUP BY DATE_TRUNC('month', payment_date)
)
SELECT
    pay_month,
    total_payments,
    high_value_count,
    COALESCE(
        pay_month::text,
        'no date recorded'
    ) AS safe_date
FROM monthly_payments
ORDER BY pay_month ASC NULLS LAST;