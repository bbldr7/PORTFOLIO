#일별 매출액과 방문자수

WITH daily_sales AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        SUM(price) AS daily_revenue
    FROM sitebehavior
    WHERE event_type = 'purchase'
    AND event_time BETWEEN '2019-10-01' AND '2020-02-29'
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
), daily_users AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        COUNT(DISTINCT user_id) AS users
    FROM sitebehavior
    WHERE event_time BETWEEN '2019-10-01' AND '2020-02-29'
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
)
SELECT 
    S.date_at,
    U.users,
    COALESCE(S.daily_revenue, 0) AS daily_revenue
FROM daily_sales S
LEFT JOIN daily_users U ON U.date_at = S.date_at
ORDER BY S.date_at;

#일별 매출액과 구매전환율
WITH daily_sales AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        SUM(price) AS daily_revenue
    FROM sitebehavior
    WHERE event_type = 'purchase'
    AND event_time BETWEEN '2019-10-01' AND '2020-02-29'
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
), daily_users AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        COUNT(DISTINCT user_id) AS users
    FROM sitebehavior
    WHERE event_time BETWEEN '2019-10-01' AND '2020-02-29'
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
), daily_pu AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        COUNT(DISTINCT user_id) AS pu
    FROM sitebehavior
    WHERE event_time BETWEEN '2019-10-01' AND '2020-02-29'
    AND event_type = 'purchase'
	AND price > 0 
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
)
SELECT 
    U.date_at,
    U.users,
    P.pu,
    ROUND(P.pu/U.users*100, 2) AS CR,
    COALESCE(s.daily_revenue, 0) AS daily_revenue
FROM daily_sales S
LEFT JOIN daily_users U ON S.date_at = U.date_at
LEFT JOIN daily_pu P ON S.date_at = P.date_at
ORDER BY U.date_at;


#일별 매출액과 객단가
WITH daily_sales AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        SUM(price) AS daily_revenue
    FROM sitebehavior
    WHERE event_type = 'purchase'
    AND event_time BETWEEN '2019-10-01' AND '2020-02-29'
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
), daily_pu AS (
    SELECT 
        DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
        COUNT(DISTINCT user_id) AS pu
    FROM sitebehavior
    WHERE event_time BETWEEN '2019-10-01' AND '2020-02-29'
    AND event_type = 'purchase'
	AND price > 0 
    GROUP BY DATE_FORMAT(event_time, '%Y-%m-%d')
)
SELECT 
    S.date_at,
    P.pu,
    COALESCE(S.daily_revenue, 0) AS daily_revenue,
    ROUND(COALESCE(S.daily_revenue, 0) / P.pu, 2) AS ARPPU
FROM daily_sales S
LEFT JOIN daily_pu P ON S.date_at = P.date_at
ORDER BY S.date_at;


#운영 제품 객단가

-- product_id별 avg(price)
WITH ProductPrices AS (
    SELECT 
        product_id,
        AVG(price) AS average_price
    FROM 
        sitebehavior
    WHERE
		price>0
    GROUP BY 
        product_id
)
-- 가격 별 제품 비교
SELECT
    product_id,
    average_price,
    COUNT(*) AS product_count,
    (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ProductPrices)) AS product_ratio
FROM
    ProductPrices
GROUP BY
    product_id, average_price
ORDER BY
    average_price;



#일별 구매수
SELECT DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
	   COUNT(event_type) AS purchase
FROM sitebehavior
WHERE price > 0 
  AND event_type = 'purchase'
GROUP BY date_at;

#일별 VIEW수
SELECT DATE_FORMAT(event_time, '%Y-%m-%d') AS date_at,
	   COUNT(event_type) AS view
FROM sitebehavior
WHERE event_type = 'view'
GROUP BY date_at;


-- 포로모션 기간 별 매출
select sum(price) from sitebehavior where date_format(event_time, '%Y-%m-%d') >= '2020-02-24' and date_format(event_time, '%Y-%m-%d') <= '2020-02-29' and event_type = 'purchase' limit 999999;

-- 프로모션 기간 중 유저 수 및 구매 횟수
 select count(*), count(distinct(user_id)) from sitebehavior where date_format(event_time, '%Y-%m-%d') >= '2020-02-24' and date_format(event_time, '%Y-%m-%d') <= '2020-02-29' and event_type = 'purchase';



 -- 프로모션 효과 검증
 select distinct(product_id), price, brand from sitebehavior where brand = 'patrisa' and date_format(event_time, '%Y-%m') = '2019-10';
 -- 프로모션 기간 중 브랜드 별 구매 횟수
 select brand, count(*) from sitebehavior where date_format(event_time, '%Y-%m-%d') >= '2019-10-07' and date_format(event_time, '%Y-%m-%d') <= '2019-10-20' and event_type = 'purchase' group by brand order by count(*) desc;
 -- 월별 전체 구매 횟수
 select count(*), count(distinct(user_id)), date_format(event_time, '%Y-%m') from sitebehavior where event_type = 'view' group by date_format(event_time, '%Y-%m');
 
 
 
 -- 브랜드 인기 순위 매기기 및 프로모션 기간 중 평균 순위 산출
alter table 1pro add column row_num INT;
select * from 1pro limit 3;

ALTER TABLE `8pro` CHANGE `count(*)` `OC` INT;
-- 랭크
alter table 8pro add column row_num INT;
CREATE TEMPORARY TABLE temp_table as
SELECT 
    @row_num := @row_num + 1 AS row_num,
    t.OC
FROM 
    `8pro` t, (SELECT @row_num := 0) r
ORDER BY 
    OC;
    
    SET SQL_SAFE_UPDATES = 0;
    
    UPDATE `8pro` t
JOIN temp_table temp ON t.OC = temp.OC
SET t.row_num = temp.row_num;

SET SQL_SAFE_UPDATES = 1;

DROP TEMPORARY TABLE temp_table;

select * from 8pro limit 5;


-- brand rank
CREATE TABLE united_table;
DROP TABLE IF EXISTS united_table;

CREATE TABLE united_table AS
SELECT
    t1.brand,
    t1.row_num AS row_num1,
    t2.row_num AS row_num2,
    t3.row_num AS row_num3,
    t4.row_num AS row_num4,
    t5.row_num AS row_num5,
    t6.row_num AS row_num6,
    t7.row_num AS row_num7,
    t8.row_num AS row_num8
FROM
    1pro t1
JOIN
    2pro t2 ON t1.brand = t2.brand
JOIN
    3pro t3 ON t2.brand = t3.brand
JOIN
    4pro t4 ON t3.brand = t4.brand
JOIN
    5pro t5 ON t4.brand = t5.brand
JOIN
    6pro t6 ON t5.brand = t6.brand
JOIN
    7pro t7 ON t6.brand = t7.brand
JOIN
    8pro t8 ON t7.brand = t8.brand;
    
    select * from united_table limit 5;
    
   SELECT 
    brand, 
    (row_num1 + row_num2 + row_num3 + row_num4 + row_num5 + row_num6 + row_num7 + row_num8) / 8 AS avg_row_num
FROM 
    united_table;