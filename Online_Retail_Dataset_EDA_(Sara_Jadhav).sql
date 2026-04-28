---ONLINE RETAIL DATASET EDA---

/* STEP 1: CREATING TABLES */

---Online Retail Full Data Table

DROP TABLE IF EXISTS retail_full;

CREATE TABLE retail_full (
    Invoice_No VARCHAR(20),
    Stock_Code VARCHAR(20),
    Description TEXT,
    Quantity INT,
    Invoice_Date TEXT,
    Unit_Price NUMERIC,
    Customer_ID VARCHAR(20),
    Country VARCHAR(50),
    Revenue NUMERIC,
    Year INT,
    Month TEXT,
    Month_Name VARCHAR(20),
    Day INT,
    Hour INT,
    DayOfWeek VARCHAR(20)
);

---Online Retail Customers Data Table

DROP TABLE IF EXISTS retail_customers;

CREATE TABLE retail_customers (
    Invoice_No VARCHAR(20),
    Stock_Code VARCHAR(20),
    Description TEXT,
    Quantity INT,
    Invoice_Date TEXT,
    Unit_Price NUMERIC,
    Customer_ID VARCHAR(20),
    Country VARCHAR(50),
    Revenue NUMERIC,
    Year INT,
    Month TEXT,
    Month_Name VARCHAR(20),
    Day INT,
    Hour INT,
    DayOfWeek VARCHAR(20),
    InvoiceMonth VARCHAR(10),
    CohortMonth VARCHAR(10),
    CohortIndex INT
);

/* STEP 2: BASIC CHECKS */

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'retail_full';

SELECT COUNT(*) FROM retail_full;
SELECT COUNT(*) FROM retail_customers;

/* STEP 3: DATA CLEANING IN SQL */

---Missing values check

SELECT 
COUNT(*) FILTER (WHERE Description IS NULL) AS missing_description,
COUNT(*) FILTER (WHERE Customer_ID IS NULL) AS missing_customer
FROM retail_full;

SELECT DISTINCT Customer_ID
FROM retail_full
LIMIT 20;

SELECT COUNT(*) AS missing_customer_ids
FROM retail_full
WHERE Customer_ID IS NULL
   OR Customer_ID = ''
   OR Customer_ID = 'NA'
   OR Customer_ID = '<NA>';

---Checking Negative Values

SELECT *
FROM retail_full
WHERE Quantity < 0 OR Revenue < 0;

---Remove duplicates

SELECT *,
ROW_NUMBER() OVER (
PARTITION BY Invoice_No, Stock_Code, Quantity
ORDER BY Invoice_Date
) AS rn
FROM retail_full;

---Then:

DELETE FROM retail_full
WHERE ctid IN (
    SELECT ctid FROM (
        SELECT ctid,
        ROW_NUMBER() OVER (
        PARTITION BY Invoice_No, Stock_Code, Quantity
        ORDER BY Invoice_Date
        ) AS rn
        FROM retail_full
    ) t
    WHERE rn > 1
);

/* STEP 4: BASIC ANALYSIS */

---Total Revenue

SELECT SUM(Revenue) FROM retail_full;

---Average Order Value

SELECT AVG(Revenue) FROM retail_full;

/* STEP 5: TIME-BASED ANALYSIS */

---Monthly Sales

SELECT Month, SUM(Revenue) AS total_revenue
FROM retail_full
GROUP BY Month
ORDER BY Month;

---Sales by Day of Week

SELECT DayOfWeek, SUM(Revenue) AS revenue
FROM retail_full
GROUP BY DayOfWeek
ORDER BY revenue DESC;

---Hourly Sales Trend

SELECT Hour, SUM(Revenue) AS revenue
FROM retail_full
GROUP BY Hour
ORDER BY Hour;

/* STEP 6: COUNTRY ANALYSIS */

---Top Countries by Quantity for Customers Data

SELECT Country,
SUM(Quantity) AS quantity,
COUNT(DISTINCT Customer_ID) AS customers
FROM retail_customers
GROUP BY Country
ORDER BY quantity DESC;

---Top Countries by Revenue for Customers Data

SELECT Country,
SUM(Revenue) AS revenue,
COUNT(DISTINCT Customer_ID) AS customers
FROM retail_customers
GROUP BY Country
ORDER BY revenue DESC;

---Top Countries by Quantity for Full Data

SELECT Country,
SUM(Quantity) AS quantity,
COUNT(DISTINCT Customer_ID) AS customers
FROM retail_full
GROUP BY Country
ORDER BY quantity DESC;

---Top Countries by Revenue for Full Data

SELECT Country,
SUM(Revenue) AS revenue,
COUNT(DISTINCT Customer_ID) AS customers
FROM retail_full
GROUP BY Country
ORDER BY revenue DESC;

/* STEP 7: PRODUCT ANALYSIS */

---Top Products by Quantity for Customers Data

SELECT Description,
SUM(Quantity) AS total_sold
FROM retail_customers
GROUP BY Description
ORDER BY total_sold DESC
LIMIT 10;

---Top Products by Revenue for Customers Data

SELECT Description,
SUM(Revenue) AS revenue
FROM retail_customers
GROUP BY Description
ORDER BY revenue DESC
LIMIT 10;

---Top Products by Quantity for Full Data

SELECT Description,
SUM(Quantity) AS total_sold
FROM retail_full
GROUP BY Description
ORDER BY total_sold DESC
LIMIT 10;

---Top Products by Revenue for Full Data

SELECT Description,
SUM(Revenue) AS revenue
FROM retail_full
GROUP BY Description
ORDER BY revenue DESC
LIMIT 10;

---Product Price Sensitivity

SELECT 
    Description,
    CORR(Unit_Price, Quantity) AS price_sensitivity
FROM retail_full
GROUP BY Description
HAVING COUNT(*) > 50
ORDER BY price_sensitivity;

/* STEP 8: CUSTOMER ANALYSIS */

---Top Customers by Quantity for Customers Data

SELECT Customer_ID,
SUM(Quantity) AS total_sold
FROM retail_customers
GROUP BY Customer_ID
ORDER BY total_sold DESC
LIMIT 10;

---Top Customers by Revenue for Customers Data

SELECT Customer_ID,
SUM(Revenue) AS total_spent
FROM retail_customers
GROUP BY Customer_ID
ORDER BY total_spent DESC
LIMIT 10;

---Top Customers by Quantity for Full Data

SELECT Customer_ID,
SUM(Quantity) AS total_sold
FROM retail_full
GROUP BY Customer_ID
ORDER BY total_sold DESC
LIMIT 10;

---Top Customers by Revenue for Full Data

SELECT Customer_ID,
SUM(Revenue) AS total_spent
FROM retail_full
GROUP BY Customer_ID
ORDER BY total_spent DESC
LIMIT 10;

/* STEP 9: ADVANCED (WINDOW FUNCTIONS) */

---Customer Ranking

SELECT Customer_ID,
SUM(Revenue) AS total_spent,
RANK() OVER (ORDER BY SUM(Revenue) DESC) AS rank
FROM retail_customers
GROUP BY Customer_ID;

/* STEP 10: RFM ANALYSIS */

WITH max_date AS (
    SELECT MAX(TO_TIMESTAMP(Invoice_Date, 'MM/DD/YYYY HH24:MI')) AS max_dt
    FROM retail_customers
),

rfm AS (
    SELECT 
        Customer_ID,

        -- Recency 
        DATE_PART(
            'day',
            (SELECT max_dt FROM max_date) -
            MAX(TO_TIMESTAMP(Invoice_Date, 'MM/DD/YYYY HH24:MI'))
        ) AS recency,

        -- Frequency
        COUNT(DISTINCT Invoice_No) AS frequency,

        -- Monetary
        SUM(Revenue) AS monetary

    FROM retail_customers
    GROUP BY Customer_ID
)

, rfm_scores AS (
    SELECT 
        *,
        
        -- Recency Score (LOW recency = better)
        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
        
        -- Frequency Score (HIGH = better)
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        
        -- Monetary Score (HIGH = better)
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
        
    FROM rfm
)

SELECT 
    *,
    
    -- Combined RFM Score
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    
    -- Customer Segmentation
    CASE 
        WHEN r_score = 5 AND f_score = 5 AND m_score = 5 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
        ELSE 'Average Customers'
    END AS customer_segment

FROM rfm_scores
ORDER BY rfm_score DESC;

/* STEP 11: COHORT ANALYSIS */

SELECT CohortMonth,
CohortIndex,
COUNT(DISTINCT Customer_ID) AS users
FROM retail_customers
GROUP BY CohortMonth, CohortIndex
ORDER BY CohortMonth, CohortIndex;

---Retention Rate

SELECT *,
ROUND(
    users * 100.0 / FIRST_VALUE(users) OVER (PARTITION BY CohortMonth ORDER BY CohortIndex),
2) AS retention_rate
FROM (
    SELECT CohortMonth,
    CohortIndex,
    COUNT(DISTINCT Customer_ID) AS users
    FROM retail_customers
    GROUP BY CohortMonth, CohortIndex
) t;

/* STEP 12: EXTRA OBSERVATIONS */

---Repeat vs New Customers

SELECT Customer_ID,
COUNT(DISTINCT Invoice_No) AS orders
FROM retail_customers
GROUP BY Customer_ID
HAVING COUNT(DISTINCT Invoice_No) > 1;

---Basket Size (Items per Order)

SELECT Invoice_No,
SUM(Quantity) AS total_items
FROM retail_full
GROUP BY Invoice_No;

---Revenue Concentration (Top Customers Contribution)

SELECT 
    SUM(Revenue) FILTER (WHERE rank <= 10) * 100.0 / SUM(Revenue) AS top_10_pct
FROM (
    SELECT Customer_ID, SUM(Revenue) AS Revenue,
           RANK() OVER (ORDER BY SUM(Revenue) DESC) AS rank
    FROM retail_customers
    GROUP BY Customer_ID
) t;

---Order Cancellation Detection

SELECT *
FROM retail_full
WHERE Invoice_No LIKE 'C%';

/* STEP 13: FINAL INSIGHT TABLE */

---Business Summary Table

SELECT 
COUNT(DISTINCT Customer_ID) AS total_customers,
COUNT(DISTINCT Invoice_No) AS total_orders,
SUM(Revenue) AS total_revenue,
AVG(Revenue) AS avg_order_value
FROM retail_customers;

---KPI Dashboard Table

SELECT 
    'Revenue' AS metric, SUM(Revenue) AS value
FROM retail_full

UNION ALL

SELECT 
    'Orders', COUNT(DISTINCT Invoice_No)
FROM retail_full

UNION ALL

SELECT 
    'Customers', COUNT(DISTINCT Customer_ID)
FROM retail_customers;