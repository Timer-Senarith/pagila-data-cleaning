/*
Timer Senarith | ALY6420 | Lab 7: Complex Data Types
Run in the database containing the ZoomZoom public tables.
Source for the reference CTEs: Canvas Module 10.5.
ZoomZoom schema and array pattern: Packt, SQL for Data Analytics, Fourth Edition,
Datasets/data.dump and Chapter 11, Exercises 11.01 and 11.02.
*/

-- Part A: List the JSON and native array columns.
SELECT table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND data_type IN ('jsonb', 'json', 'ARRAY')
ORDER BY table_name, column_name;

/* Part A output from Neon
table_name,column_name,data_type,udt_name
actor_info,film_info,jsonb,jsonb
customer_sales,customer_json,jsonb,jsonb
customer_sales_copy,customer_json,jsonb,jsonb
film,special_features,ARRAY,_text
*/

-- Q1: Extract text and a numeric scalar.
WITH ref_products(product_id, model, specs, category_tags) AS (
    VALUES
    (1, 'X1 Pro',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 45, "range_km": 60}, "regions": ["Northeast", "Southeast"]}'::jsonb,
       ARRAY['EV', 'Commuter']),
    (2, 'X2 Cargo',
       '{"category": "Cargo", "performance": {"max_speed_kph": 32, "range_km": 80}, "regions": ["Midwest", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Commercial']),
    (3, 'X1 Base',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 40, "range_km": 55}, "regions": ["Northeast", "Northwest"]}'::jsonb,
       ARRAY['EV', 'Budget']),
    (4, 'X3 Pro',
       '{"category": "Cargo", "performance": {"max_speed_kph": 30, "range_km": 90}, "regions": ["Southeast", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Pro'])
)
SELECT model, specs ->> 'category' AS category,
       (specs -> 'performance' ->> 'range_km')::integer AS range_km
FROM ref_products
ORDER BY product_id;

-- ZoomZoom: one row per recorded sale.
WITH purchases AS (
    SELECT jsonb_array_elements(customer_json -> 'sales') AS sale
    FROM public.customer_sales
    WHERE jsonb_typeof(customer_json -> 'sales') = 'array'
)
SELECT sale ->> 'product_name' AS model,
       sale ->> 'sales_transaction_date' AS transaction_timestamp_text,
       (sale ->> 'sales_amount')::numeric AS sale_amount
FROM purchases
WHERE sale ->> 'product_name' IS NOT NULL
ORDER BY model, sale_amount;

/* The -> operator keeps the performance object or sales array as JSONB so that
the next step can navigate it. At a scalar value, ->> gives SQL text that I can
display or cast to a number. Using -> for a name would return a JSON string,
including quotation marks in its JSON representation. */

-- Q2: Navigate a nested path and compute a new measure.
WITH ref_products(product_id, model, specs, category_tags) AS (
    VALUES
    (1, 'X1 Pro',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 45, "range_km": 60}, "regions": ["Northeast", "Southeast"]}'::jsonb,
       ARRAY['EV', 'Commuter']),
    (2, 'X2 Cargo',
       '{"category": "Cargo", "performance": {"max_speed_kph": 32, "range_km": 80}, "regions": ["Midwest", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Commercial']),
    (3, 'X1 Base',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 40, "range_km": 55}, "regions": ["Northeast", "Northwest"]}'::jsonb,
       ARRAY['EV', 'Budget']),
    (4, 'X3 Pro',
       '{"category": "Cargo", "performance": {"max_speed_kph": 30, "range_km": 90}, "regions": ["Southeast", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Pro'])
)
SELECT model, specs ->> 'category' AS category,
       (specs -> 'performance' ->> 'max_speed_kph')::numeric AS max_speed_kph,
       round((specs -> 'performance' ->> 'max_speed_kph')::numeric * 0.621371, 2)
           AS max_speed_mph
FROM ref_products
ORDER BY product_id;

-- ZoomZoom: extract the first recorded sale in each customer's JSON array.
WITH first_sale AS (
    SELECT (customer_json ->> 'customer_id')::bigint AS customer_id,
           customer_json -> 'sales' -> 0 ->> 'product_name' AS model,
           (customer_json -> 'sales' -> 0 ->> 'sales_amount')::numeric AS amount
    FROM public.customer_sales
)
SELECT customer_id, model, amount, round(amount * 0.90, 2) AS amount_after_10_pct_discount
FROM first_sale
WHERE amount IS NOT NULL
ORDER BY customer_id;

/* Chaining operators makes each step readable, especially when a path mixes
object keys and an array position. jsonb_extract_path_text() returns SQL text
at the end of the path in one call, which is convenient when the path components
are supplied together. */

-- Q3: Expand regions and count distinct products per region.
WITH ref_products(product_id, model, specs, category_tags) AS (
    VALUES
    (1, 'X1 Pro',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 45, "range_km": 60}, "regions": ["Northeast", "Southeast"]}'::jsonb,
       ARRAY['EV', 'Commuter']),
    (2, 'X2 Cargo',
       '{"category": "Cargo", "performance": {"max_speed_kph": 32, "range_km": 80}, "regions": ["Midwest", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Commercial']),
    (3, 'X1 Base',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 40, "range_km": 55}, "regions": ["Northeast", "Northwest"]}'::jsonb,
       ARRAY['EV', 'Budget']),
    (4, 'X3 Pro',
       '{"category": "Cargo", "performance": {"max_speed_kph": 30, "range_km": 90}, "regions": ["Southeast", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Pro'])
),
product_regions AS (
    SELECT p.product_id, r.region
    FROM ref_products AS p
    LEFT JOIN LATERAL jsonb_array_elements_text(
        CASE WHEN jsonb_typeof(p.specs -> 'regions') = 'array'
             THEN p.specs -> 'regions' ELSE '[]'::jsonb END
    ) AS r(region) ON true
)
SELECT region, count(DISTINCT product_id) AS products
FROM product_regions
WHERE region IS NOT NULL
GROUP BY region
ORDER BY products DESC, region;

-- ZoomZoom equivalent: count distinct customers for each purchased model.
WITH customer_models AS (
    SELECT (cs.customer_json ->> 'customer_id')::bigint AS customer_id, m.model
    FROM public.customer_sales AS cs
    LEFT JOIN LATERAL jsonb_array_elements_text(
        jsonb_path_query_array(cs.customer_json, '$.sales[*].product_name')
    ) AS m(model) ON true
)
SELECT model, count(DISTINCT customer_id) AS customers
FROM customer_models
WHERE model IS NOT NULL
GROUP BY model
ORDER BY customers DESC, model;

/* A SQL NULL document and a document without the regions key both yield no
region elements. The CASE supplies an empty array and LEFT JOIN LATERAL keeps
the parent available for auditing. The final filter excludes its NULL region
from the frequency counts. */

-- Q4: Membership, containment and overlap.
WITH ref_products(product_id, model, specs, category_tags) AS (
    VALUES
    (1, 'X1 Pro',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 45, "range_km": 60}, "regions": ["Northeast", "Southeast"]}'::jsonb,
       ARRAY['EV', 'Commuter']),
    (2, 'X2 Cargo',
       '{"category": "Cargo", "performance": {"max_speed_kph": 32, "range_km": 80}, "regions": ["Midwest", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Commercial']),
    (3, 'X1 Base',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 40, "range_km": 55}, "regions": ["Northeast", "Northwest"]}'::jsonb,
       ARRAY['EV', 'Budget']),
    (4, 'X3 Pro',
       '{"category": "Cargo", "performance": {"max_speed_kph": 30, "range_km": 90}, "regions": ["Southeast", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Pro'])
)
SELECT product_id, model FROM ref_products
WHERE 'EV' = ANY(category_tags)
ORDER BY product_id;

WITH ref_products(product_id, model, specs, category_tags) AS (
    VALUES
    (1, 'X1 Pro',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 45, "range_km": 60}, "regions": ["Northeast", "Southeast"]}'::jsonb,
       ARRAY['EV', 'Commuter']),
    (2, 'X2 Cargo',
       '{"category": "Cargo", "performance": {"max_speed_kph": 32, "range_km": 80}, "regions": ["Midwest", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Commercial']),
    (3, 'X1 Base',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 40, "range_km": 55}, "regions": ["Northeast", "Northwest"]}'::jsonb,
       ARRAY['EV', 'Budget']),
    (4, 'X3 Pro',
       '{"category": "Cargo", "performance": {"max_speed_kph": 30, "range_km": 90}, "regions": ["Southeast", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Pro'])
)
SELECT product_id, model FROM ref_products
WHERE category_tags @> ARRAY['EV','Commuter']
ORDER BY product_id;

WITH ref_products(product_id, model, specs, category_tags) AS (
    VALUES
    (1, 'X1 Pro',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 45, "range_km": 60}, "regions": ["Northeast", "Southeast"]}'::jsonb,
       ARRAY['EV', 'Commuter']),
    (2, 'X2 Cargo',
       '{"category": "Cargo", "performance": {"max_speed_kph": 32, "range_km": 80}, "regions": ["Midwest", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Commercial']),
    (3, 'X1 Base',
       '{"category": "EV Scooter", "performance": {"max_speed_kph": 40, "range_km": 55}, "regions": ["Northeast", "Northwest"]}'::jsonb,
       ARRAY['EV', 'Budget']),
    (4, 'X3 Pro',
       '{"category": "Cargo", "performance": {"max_speed_kph": 30, "range_km": 90}, "regions": ["Southeast", "Southwest"]}'::jsonb,
       ARRAY['Cargo', 'Pro'])
)
SELECT product_id, model FROM ref_products
WHERE category_tags && ARRAY['Budget','Pro']
ORDER BY product_id;

-- ZoomZoom: Chapter 11 builds native arrays from email subjects.
WITH subjects_by_customer AS (
    SELECT customer_id, array_agg(DISTINCT email_subject) AS subjects
    FROM public.emails
    WHERE email_subject IS NOT NULL
    GROUP BY customer_id
)
SELECT customer_id FROM subjects_by_customer
WHERE 'A New Year, And Some New EVs' = ANY(subjects)
ORDER BY customer_id;

WITH subjects_by_customer AS (
    SELECT customer_id, array_agg(DISTINCT email_subject) AS subjects
    FROM public.emails
    WHERE email_subject IS NOT NULL
    GROUP BY customer_id
)
SELECT customer_id FROM subjects_by_customer
WHERE subjects @> ARRAY['A New Year, And Some New EVs','Save the Planet with some Holiday Savings.']
ORDER BY customer_id;

WITH subjects_by_customer AS (
    SELECT customer_id, array_agg(DISTINCT email_subject) AS subjects
    FROM public.emails
    WHERE email_subject IS NOT NULL
    GROUP BY customer_id
)
SELECT customer_id FROM subjects_by_customer
WHERE subjects && ARRAY['A New Year, And Some New EVs','Save the Planet with some Holiday Savings.']
ORDER BY customer_id;

/* Containment (@>) answers whether a customer received both selected subjects,
as required for a campaign follow-up. Overlap (&&) includes anyone who received
at least one of the subjects, which suits a broader outreach list. */

-- Q5: Expand email subject arrays, join customers, and count reach per subject.
WITH subjects_by_customer AS (
    SELECT customer_id, array_agg(DISTINCT email_subject) AS subjects
    FROM public.emails
    WHERE email_subject IS NOT NULL
    GROUP BY customer_id
)
SELECT e.subject, count(DISTINCT c.customer_id) AS customers_reached
FROM subjects_by_customer AS a
JOIN public.customers AS c ON c.customer_id = a.customer_id
CROSS JOIN LATERAL unnest(a.subjects) AS e(subject)
GROUP BY e.subject
HAVING count(DISTINCT c.customer_id) >= 2
ORDER BY customers_reached DESC, e.subject;

/* unnest() turns a customer's subject array into one row per customer-subject
pair; the threshold keeps subjects shared by multiple customers. With a normalized
customer-subject table, those pairs would already be rows, so I could join and
group them directly. */

-- Q6: Average numeric attributes across the sale objects.
SELECT attr.key AS attribute, avg(attr.value::numeric) AS average_value
FROM public.customer_sales AS cs
CROSS JOIN LATERAL jsonb_array_elements(
    CASE WHEN jsonb_typeof(cs.customer_json -> 'sales') = 'array'
         THEN cs.customer_json -> 'sales' ELSE '[]'::jsonb END
) AS p(sale)
CROSS JOIN LATERAL jsonb_each(
    CASE WHEN jsonb_typeof(p.sale) = 'object'
         THEN p.sale ELSE '{}'::jsonb END
) AS attr(key, value)
WHERE jsonb_typeof(attr.value) = 'number'
GROUP BY attr.key
ORDER BY average_value DESC, attribute;

/* Q6 EXPLAIN ANALYZE output from Neon
Sort  (cost=157959.90..157959.91 rows=1 width=64) (actual time=177.513..180.828 rows=2.00 loops=1)
  Sort Key: (avg((attr.value)::numeric)) DESC, attr.key
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=2109
  ->  Finalize GroupAggregate  (cost=157959.64..157959.89 rows=1 width=64) (actual time=177.507..180.824 rows=2.00 loops=1)
        Group Key: attr.key
        Buffers: shared hit=2109
        ->  Gather Merge  (cost=157959.64..157959.87 rows=2 width=64) (actual time=177.499..180.814 rows=4.00 loops=1)
              Workers Planned: 1
              Workers Launched: 1
              Buffers: shared hit=2109
              ->  Sort  (cost=156959.63..156959.63 rows=1 width=64) (actual time=175.075..175.116 rows=2.00 loops=2)
                    Sort Key: attr.key
                    Sort Method: quicksort  Memory: 25kB
                    Buffers: shared hit=2109
                    Worker 0:  Sort Method: quicksort  Memory: 25kB
                    ->  Partial HashAggregate  (cost=156959.60..156959.62 rows=1 width=64) (actual time=175.061..175.102 rows=2.00 loops=2)
                          Group Key: attr.key
                          Batches: 1  Memory Usage: 32kB
                          Buffers: shared hit=2101
                          Worker 0:  Batches: 1  Memory Usage: 32kB
                          Buffers: shared hit=2101
                          ->  Nested Loop  (cost=0.03..134900.78 rows=2941176 width=64) (actual time=0.028..152.291 rows=37711.00 loops=2)
                                Buffers: shared hit=2101
                                ->  Nested Loop  (cost=0.01..61219.13 rows=2941176 width=32) (actual time=0.017..49.223 rows=18855.50 loops=2)
                                      Buffers: shared hit=2101
                                      ->  Parallel Seq Scan on customer_sales cs  (cost=0.00..2395.12 rows=29412 width=307) (actual time=0.005..2.843 rows=25000.00 loops=2)
                                            Buffers: shared hit=2101
                                      ->  Function Scan on jsonb_array_elements p  (cost=0.01..1.01 rows=100 width=32) (actual time=0.001..0.001 rows=0.75 loops=50000)
                                ->  Memoize  (cost=0.02..1.52 rows=1 width=64) (actual time=0.003..0.004 rows=2.00 loops=37711)
                                      Cache Key: p.sale
                                      Cache Mode: binary
                                      Hits: 0  Misses: 19365  Evictions: 0  Overflows: 0  Memory Usage: 6253kB
                                      Worker 0:  Hits: 0  Misses: 18346  Evictions: 0  Overflows: 0  Memory Usage: 5925kB
                                      ->  Function Scan on jsonb_each attr  (cost=0.01..1.51 rows=1 width=64) (actual time=0.003..0.003 rows=2.00 loops=37711)
                                            Filter: (jsonb_typeof(value) = 'number'::text)
                                            Rows Removed by Filter: 2
Planning Time: 0.101 ms
Execution Time: 181.265 ms
*/

/* The top Sort finished at 180.828 ms, the highest actual end time, which includes
the work of its children. A Parallel Seq Scan split 50,000 customer documents
between the leader and one worker because this report aggregates across all customers.
PostgreSQL called jsonb_each 37,711 times and produced 75,422 numeric key-value pairs
before combining them into two averages. At 10 million rows, I would maintain a
summary of sums and counts per numeric key during ingestion so repeated reports
could calculate each average without expanding the entire sales history again. */

/* Flattening lets the same query discover numeric keys present in different
sale records without requiring a fixed list of attributes. Each average includes
only records with a numeric value for that key. An ID can be numeric too: its
average satisfies the query but has little meaning as a business measure. */

-- Part C: Reproduce the Neon execution plan recorded directly beneath Q6.
EXPLAIN ANALYZE
SELECT attr.key AS attribute, avg(attr.value::numeric) AS average_value
FROM public.customer_sales AS cs
CROSS JOIN LATERAL jsonb_array_elements(
    CASE WHEN jsonb_typeof(cs.customer_json -> 'sales') = 'array'
         THEN cs.customer_json -> 'sales' ELSE '[]'::jsonb END
) AS p(sale)
CROSS JOIN LATERAL jsonb_each(
    CASE WHEN jsonb_typeof(p.sale) = 'object'
         THEN p.sale ELSE '{}'::jsonb END
) AS attr(key, value)
WHERE jsonb_typeof(attr.value) = 'number'
GROUP BY attr.key
ORDER BY average_value DESC, attribute;

-- Q7: Design judgment for public.customer_sales.customer_json ->> 'customer_id'.
SELECT (customer_json ->> 'customer_id')::bigint AS customer_id
FROM public.customer_sales
ORDER BY customer_id;

/* Proposed DDL for review:
ALTER TABLE public.customer_sales ADD COLUMN customer_id bigint;
*/

/*
I would move customer_id out of the customer_json document in public.customer_sales
and into a bigint column. This table stores each customer's sales together, while
public.customers already identifies that person using a relational key. A report
that combines purchase history with customer records needs a dependable way to
match the two. Keeping the identifier inside the document makes each analyst
responsible for extracting the same key and casting it to the correct type.

Two criteria guide my choice: how often the attribute is used in joins and how
important it is to enforce a consistent value. With a typed column, a customer
lookup could use a regular B-tree index. I would also check missing IDs, duplicates,
and unmatched customers before adding constraints. A foreign key could then catch
an incoming sale document assigned to an unknown customer. The column alone would
enforce the numeric type, while the foreign key would enforce the relationship.

Keeping the identifier in JSON still makes sense when the table serves as an
unaltered snapshot of an external feed. The original document is easier to replay,
and storing two editable copies of the identifier creates a risk that they drift
apart. For an analytical table, I would populate the relational key during ingestion,
retain the original payload for auditing, and use the relational key consistently
in downstream joins.
*/

-- Part D: Run the supplied query, then compare it with the correction.
WITH test_products(model, specs) AS (
    VALUES
    ('X1 Pro',   '{"category": "EV Scooter", "performance": {"max_speed_kph": 45}}'::jsonb),
    ('X2 Cargo', '{"category": "Cargo",      "performance": {"max_speed_kph": 32}}'::jsonb),
    ('X1 Base',  '{"category": "EV Scooter", "performance": {"max_speed_kph": 40}}'::jsonb),
    ('X3 Pro',   '{"category": "Cargo",      "performance": {"max_speed_kph": 30}}'::jsonb)
)
SELECT specs -> 'category' AS product_category,
       avg((specs ->> 'max_speed_kph')::numeric) AS avg_max_speed
FROM test_products
GROUP BY specs -> 'category'
ORDER BY avg_max_speed ASC;

/* Error 1: -> returns JSONB. PostgreSQL can group JSONB, so it forms two
groups, but their labels are JSON strings such as "Cargo". The requested
clean SQL text labels require ->> in the SELECT and GROUP BY expressions.

Error 2: max_speed_kph is inside performance. Reading it at the top level
returns SQL NULL in all four rows, so both averages are NULL and the output
cannot support a speed comparison.

Error 3: ASC would rank the slower category first once the numeric path is
fixed. With both original averages NULL, neither row has a meaningful rank.
DESC gives the requested fastest-first ordering.
*/

-- Part D: Corrected query. Expected: EV Scooter 42.5 kph, Cargo 31 kph.
WITH test_products(model, specs) AS (
    VALUES
    ('X1 Pro',   '{"category": "EV Scooter", "performance": {"max_speed_kph": 45}}'::jsonb),
    ('X2 Cargo', '{"category": "Cargo",      "performance": {"max_speed_kph": 32}}'::jsonb),
    ('X1 Base',  '{"category": "EV Scooter", "performance": {"max_speed_kph": 40}}'::jsonb),
    ('X3 Pro',   '{"category": "Cargo",      "performance": {"max_speed_kph": 30}}'::jsonb)
)
SELECT specs ->> 'category' AS product_category,
       avg((specs -> 'performance' ->> 'max_speed_kph')::numeric) AS avg_max_speed
FROM test_products
GROUP BY specs ->> 'category'
ORDER BY avg_max_speed DESC NULLS LAST, product_category;
