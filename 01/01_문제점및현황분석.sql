-- 일별 매출액과 일별 변화율
WITH daily_sales AS (
    SELECT 
        DATE(event_time) AS sale_date,
        SUM(price) AS daily_revenue
    FROM sitebehavior
    WHERE event_type = 'purchase'
    GROUP BY DATE(event_time)
), daily_sales_with_prev AS (
    SELECT 
        sale_date,
        daily_revenue,
        LAG(daily_revenue, 1) OVER (ORDER BY sale_date) AS prev_day_revenue
    FROM daily_sales
)
SELECT 
    sale_date,
    daily_revenue,
    ROUND((daily_revenue - prev_day_revenue) / NULLIF(prev_day_revenue, 0) * 100, 2) AS daily_revenue_change_percentage
FROM daily_sales_with_prev
ORDER BY sale_date;


# 일별 활성 사용자 수
SELECT DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at
	 , COUNT(DISTINCT user_id) AS users
FROM sitebehavior
WHERE event_time BETWEEN '2019-10-01' AND '2020-02-29'
GROUP BY 1
ORDER BY 1;


# 구매자 수 및 비율
SELECT COUNT(DISTINCT user_id) AS all_customer
     , (SELECT COUNT(DISTINCT user_id)
		FROM sitebehavior
		WHERE event_type = 'purchase') AS purchase_customer
     ,  ((SELECT COUNT(DISTINCT user_id)
		FROM sitebehavior
		WHERE event_type = 'purchase') / COUNT(DISTINCT user_id) * 100) AS pct
FROM sitebehavior;

# 구매 고객 외 행동분석
-- purchase 직전 event_type 비율 구하기

#임시 테이블 만들기
WITH UserEvents AS (
    SELECT
        user_id,
        product_id,
        event_type,
        event_time
    FROM
        sitebehavior
    ORDER BY
        user_id, product_id, event_time
),

#이전 event_type 구하기
PreviousEvent AS (
    SELECT
        user_id,
        product_id,
        LAG(event_type) OVER (PARTITION BY user_id, product_id ORDER BY event_time) AS previous_event_type,
        event_type
    FROM
        UserEvents
),

#최종 event_type이 purchase인걸 구하기
FilteredPurchases AS (
    SELECT
        product_id,
        previous_event_type
    FROM
        PreviousEvent
    WHERE
        event_type = 'purchase'
),

#직전 event_type의 종류별 개수 구하기
EventTypeCounts AS (
    SELECT
        previous_event_type,
        COUNT(*) AS event_count
    FROM
        FilteredPurchases
    GROUP BY
        previous_event_type
),

#총 구매 개수 구하기
TotalPurchases AS (
    SELECT
        COUNT(*) AS total_purchases
    FROM
        FilteredPurchases
)

#최종 비율 구하기
SELECT
    e.previous_event_type,
    e.event_count,
    t.total_purchases,
    (e.event_count * 1.0 / t.total_purchases) AS event_ratio
FROM
    EventTypeCounts e,
    TotalPurchases t;

-- p14
#재구매 비율 
WITH daily_purchases AS (
    SELECT
        user_id, DATE(event_time) AS purchase_date
    FROM sitebehavior
    WHERE event_type = 'purchase'
    GROUP BY user_id, DATE(event_time)
),
purchase_counts AS (
    SELECT
        user_id, COUNT(*) AS unique_purchase_days
    FROM daily_purchases
    GROUP BY user_id
)
SELECT
    (SELECT COUNT(DISTINCT user_id)
     FROM purchase_counts) AS total_purchase_customers,
    (SELECT COUNT(DISTINCT user_id)
     FROM purchase_counts
     WHERE unique_purchase_days >= 2) AS repeat_purchase_customers;


# 단발성 고객의 주문당 구매 상품 개수
WITH unique_purchases AS (
    SELECT 
        user_id,
        event_time
    FROM sitebehavior
    WHERE event_type = 'purchase'
    GROUP BY user_id, event_time
), purchase_counts AS (
    SELECT 
        user_id,
        COUNT(*) AS purchase_count
    FROM unique_purchases
    GROUP BY user_id
), single_purchase_users AS (
    SELECT 
        user_id
    FROM 
        purchase_counts
    WHERE 
        purchase_count = 1
), single_purchase_orders AS (
    SELECT 
        b.user_id,
        b.event_time,
        COUNT(b.product_id) AS product_count
    FROM 
        beha b
    JOIN 
        single_purchase_users spu
    ON 
        b.user_id = spu.user_id
    WHERE 
        b.event_type = 'purchase'
    GROUP BY 
        b.user_id, b.event_time
)
SELECT 
    product_count, 
    COUNT(user_id) AS user_count
FROM 
    single_purchase_orders
GROUP BY 
    product_count
ORDER BY 
    product_count;


# 구매 고객의 객단가
WITH product_events AS (
    SELECT product_id,
           COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count
    FROM cosmetics_ecommerce.sitebehavior
    WHERE price > 0
    GROUP BY product_id
),

product_percentiles AS (
    SELECT product_id, purchase_count,
           NTILE(100) OVER (ORDER BY purchase_count DESC) AS percentile_group
    FROM product_events
),

product_prices AS (
    SELECT product_id,
           AVG(price) AS average_price
    FROM cosmetics_ecommerce.sitebehavior
    WHERE price > 0
    GROUP BY product_id
)

SELECT 
    CASE 
        WHEN percentile_group <= 5 THEN 'Top 5%'
        WHEN percentile_group <= 10 THEN 'Top 10%'
        WHEN percentile_group <= 15 THEN 'Top 15%'
        WHEN percentile_group <= 20 THEN 'Top 20%'
        WHEN percentile_group <= 25 THEN 'Top 25%'
        WHEN percentile_group <= 50 THEN 'Top 50%'
        WHEN percentile_group <= 75 THEN 'Top 75%'
        ELSE 'Top 100%'
    END AS percentile_range,
    AVG(pp.average_price) AS avg_price
FROM 
    product_percentiles pr
JOIN 
    product_prices pp ON pr.product_id = pp.product_id
GROUP BY 
    percentile_range
ORDER BY 
    MIN(percentile_group);


#구매 상위 제품별 평균 구매 횟수 

-- 각 제품의 이벤트 횟수 계산
WITH product_events AS (
    SELECT product_id,
           COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count,
           COUNT(CASE WHEN event_type = 'view' THEN 1 END) AS view_count,
           COUNT(CASE WHEN event_type = 'cart' THEN 1 END) AS cart_count
    FROM cosmetics_ecommerce.sitebehavior
    GROUP BY product_id
),

-- 총 제품 수 계산
total_products AS (
    SELECT COUNT(*) AS total_count
    FROM product_events
),

-- 각 제품에 대해 랭킹
ranked_products AS (
    SELECT 
        product_id, purchase_count, view_count, cart_count,
        @curRank := @curRank + 1 AS ranking
    FROM 
        product_events, (SELECT @curRank := 0) r
    ORDER BY purchase_count DESC
),

-- 각 퍼센트 범위에 해당하는 제품을 선택하여 평균 계산
-- 상위 5% 
top_5_percent AS (
    SELECT purchase_count, view_count, cart_count
    FROM ranked_products, total_products
    WHERE ranking <= total_products.total_count * 0.05
),

-- 상위 5% ~ 10%
top_5_to_10_percent AS (
    SELECT purchase_count, view_count, cart_count
    FROM ranked_products, total_products
    WHERE ranking > total_products.total_count * 0.05 AND ranking <= total_products.total_count * 0.10
),

-- 상위 10% ~ 15%
top_10_to_15_percent AS (
    SELECT purchase_count, view_count, cart_count
    FROM ranked_products, total_products
    WHERE ranking > total_products.total_count * 0.10 AND ranking <= total_products.total_count * 0.15
),

-- 상위 15% ~ 20%
top_15_to_20_percent AS (
    SELECT purchase_count, view_count, cart_count
    FROM ranked_products, total_products
    WHERE ranking > total_products.total_count * 0.15 AND ranking <= total_products.total_count * 0.20
),

-- 상위 20% ~ 25%
top_20_to_25_percent AS (
    SELECT purchase_count, view_count, cart_count
    FROM ranked_products, total_products
    WHERE ranking > total_products.total_count * 0.20 AND ranking <= total_products.total_count * 0.25
)

-- 평균 조회
SELECT 'Top 5%' AS category, 
       AVG(purchase_count) AS avg_purchase_count, 
       AVG(view_count) AS avg_view_count, 
       AVG(cart_count) AS avg_cart_count
FROM top_5_percent

UNION ALL

SELECT 'Top 5% - 10%' AS category, 
       AVG(purchase_count) AS avg_purchase_count, 
       AVG(view_count) AS avg_view_count, 
       AVG(cart_count) AS avg_cart_count
FROM top_5_to_10_percent

UNION ALL

SELECT 'Top 10% - 15%' AS category, 
       AVG(purchase_count) AS avg_purchase_count, 
       AVG(view_count) AS avg_view_count, 
       AVG(cart_count) AS avg_cart_count
FROM top_10_to_15_percent

UNION ALL

SELECT 'Top 15% - 20%' AS category, 
       AVG(purchase_count) AS avg_purchase_count, 
       AVG(view_count) AS avg_view_count, 
       AVG(cart_count) AS avg_cart_count
FROM top_15_to_20_percent

UNION ALL

SELECT 'Top 20% - 25%' AS category, 
       AVG(purchase_count) AS avg_purchase_count, 
       AVG(view_count) AS avg_view_count, 
       AVG(cart_count) AS avg_cart_count
FROM top_20_to_25_percent;

#구매상위25% 제품의 세부 구매수
WITH product_events AS (
    SELECT product_id,
           COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count
    FROM cosmetics_ecommerce.sitebehavior
    GROUP BY product_id
),

product_ranks AS (
    SELECT product_id, purchase_count,
           NTILE(4) OVER (ORDER BY purchase_count DESC) AS quartile
    FROM product_events
)

SELECT product_id, purchase_count
FROM product_ranks
WHERE quartile = 1
ORDER BY purchase_count DESC;



# 쇼핑카트 포기율 
-- purchase 카운트(user_id 구분X)
select count(*)
from sitebehavior
WHERE event_type = 'purchase';

-- cart 카운트(user_id 구분X)
select count(*)
from sitebehavior
WHERE event_type = 'cart';

