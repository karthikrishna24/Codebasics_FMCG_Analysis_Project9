-- UPDATING THE TABLE

START TRANSACTION; 

UPDATE fact_events
SET `quantity_sold_after_promo` = `quantity_sold_after_promo` * 2 
WHERE promo_type = "BOGOF";

COMMIT;

-- -------------------------------------------------------------------------------------------
-- 1
                    
SELECT
    product_code,
    product_name
FROM
    dim_products
WHERE
    product_code IN (
        SELECT
            DISTINCT(product_code)
        FROM
            fact_events
        WHERE
            base_price >= 500
            AND promo_type = 'BOGOF'
    );
    
-- -------------------------------------------------------------------------------------------
-- 2

SELECT 
	city,
    COUNT(*) AS Count 
FROM 
	dim_stores 
GROUP BY 
	city
ORDER BY 
	2 DESC;

-- OR 

SELECT 
    city,
    COUNT(DISTINCT(a.store_id)) AS Count 
FROM 
    fact_events a 
JOIN 
    dim_stores b 
    ON a.store_id = b.store_id
GROUP BY 
    city 
ORDER BY 
    Count DESC;
    
-- -------------------------------------------------------------------------------------------
-- 3

WITH CTE AS (
    SELECT 
        campaign_id,
        quantity_sold_before_promo,
        quantity_sold_after_promo,
        base_price AS base_price_bf,
        CASE 
            WHEN promo_type = '50% OFF'      THEN base_price * 0.5 
            WHEN promo_type = '25% OFF'      THEN base_price * 0.75
            WHEN promo_type = '33% OFF'      THEN base_price * 0.67
            WHEN promo_type = '500 Cashback' THEN base_price - 500
            WHEN promo_type = 'BOGOF'        THEN base_price / 2
        END AS base_price_af
    FROM 
        fact_events
)

SELECT 
    c.campaign_name, 
    CONCAT(ROUND(SUM(e.base_price_bf* e.quantity_sold_before_promo)/1000000,2),"M") AS 'total_revenue(before_promotion)',
    CONCAT(ROUND(SUM(e.base_price_af * e.quantity_sold_after_promo)/1000000,2),"M")AS 'total_revenue(after_promotion)'
FROM 
    dim_campaigns c 
JOIN 
    CTE e 
ON 
    c.campaign_id = e.campaign_id
GROUP BY 
    c.campaign_name;
    
-- -------------------------------------------------------------------------------------------
-- 4

WITH CTE AS (
    SELECT 
        category,
        ROUND(
            (100 * (SUM(quantity_sold_after_promo) - SUM(quantity_sold_before_promo)) / SUM(quantity_sold_before_promo)), 2
        ) AS 'ISU'
    FROM 
        fact_events e
    JOIN 
        dim_products p ON e.product_code = p.product_code
    WHERE 
        campaign_id = 'CAMP_DIW_01'
    GROUP BY 
        category
    ORDER BY 
        2 DESC
)

SELECT 
    category,
    ISU AS 'ISU%',
    RANK() OVER(ORDER BY ISU DESC) AS 'Rank'
FROM 
    CTE;

-- -------------------------------------------------------------------------------------------
-- 5

WITH CTE1 AS (
    SELECT 
        product_code,
        campaign_id,
        quantity_sold_before_promo,
        quantity_sold_after_promo,
        base_price AS base_price_bf,
        CASE 
            WHEN promo_type = '50% OFF'      THEN base_price * 0.5 
            WHEN promo_type = '25% OFF'      THEN base_price * 0.75
            WHEN promo_type = '33% OFF'      THEN base_price * 0.67
            WHEN promo_type = '500 Cashback' THEN base_price - 500
            WHEN promo_type = 'BOGOF'        THEN base_price / 2
        END AS base_price_af
    FROM 
        fact_events
),

CTE AS (
    SELECT
        product_name,
        ROUND((
            (SUM(base_price_af * quantity_sold_after_promo) -
            SUM(base_price_bf * quantity_sold_before_promo)) /
            SUM(base_price_bf * quantity_sold_before_promo)
        ), 2) * 100 AS IR
    FROM 
        CTE1 e
    JOIN 
        dim_products p ON e.product_code = p.product_code
    GROUP BY 
        product_name
)

SELECT 
    a.product_name,
    category,
    IR AS 'IR%',
    RANK() OVER(ORDER BY IR DESC) AS Rank_order
FROM 
    CTE a
JOIN 
    dim_products b ON a.product_name = b.product_name
LIMIT 5;