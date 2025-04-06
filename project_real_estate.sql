--Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
 ),
 --Делим все объявления на 2 категории - Санкт-Петербург и Ленинградская Область
 --Выделяем 4 категории в зависимости от времени продажи объявления
 category_data AS(
 	SELECT *,
 	CASE
 		WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
 		ELSE 'ЛенОбл'
 	END AS location,
 	CASE
 		WHEN days_exposition BETWEEN 1 AND 30 THEN 'в течение месяца'
 		WHEN days_exposition BETWEEN 31 AND 90 THEN 'в течение квартала'
 		WHEN days_exposition BETWEEN 91 AND 180 THEN 'в течение полугода'
 		WHEN days_exposition >= 181 THEN 'более полугода'
 		ELSE 'нет информации'
 	END AS sale_time,
 	last_price / total_area AS rub_kv_m,
 	last_price
 	FROM real_estate.flats
 	NATURAL JOIN real_estate.advertisement
	WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' AND (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018) 
 )   
--Группируем объявления по локации и времени продажи, подсчитываем основные статистические показатели
SELECT 
	location, 
	sale_time, 
	COUNT(id) AS count_adv,
	ROUND(COUNT(id)::numeric / SUM(COUNT(id)) OVER(PARTITION BY location), 2) AS adv_part,
	ROUND((SELECT COUNT(id) FROM category_data WHERE rooms = 0) / COUNT(id)::NUMERIC * 100) AS studio_percent,
	ROUND((SELECT COUNT(id) FROM category_data WHERE is_apartment = 1) / COUNT(id)::NUMERIC * 100) AS apartments_percent,
	ROUND((SELECT COUNT(id) FROM category_data WHERE open_plan = 1) / COUNT(id)::NUMERIC * 100) AS open_plan_percent,
	ROUND(AVG(rub_kv_m::NUMERIC)) AS avg_cost_per_meter,
	ROUND(AVG(total_area::NUMERIC)) AS avg_total_area,
	ROUND(AVG(ceiling_height::numeric), 3) AS avg_ceiling_height,
	ROUND(AVG(airports_nearest::NUMERIC)) AS avg_airports_nearest,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS mediana_floors,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS mediana_parks_around3000,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS mediana_ponds_around3000
FROM category_data
GROUP BY location, sale_time
ORDER BY LOCATION DESC, AVG(days_exposition);
--Сезонность объявлений
set lc_time = 'ru_RU';
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
--Подсчитываем количество продаж в каждом месяце
sale_stat AS(
SELECT 
	EXTRACT(month FROM first_day_exposition::date + INTERVAL '1 days' * days_exposition) AS num_month,
	TO_CHAR((first_day_exposition::date + INTERVAL '1 days' * days_exposition), 'TMmon') AS month_name,
	COUNT(id) AS cnt_sold,
	ROUND(AVG(last_price/total_area)::NUMERIC) AS avg_rub_m_new,
	ROUND(AVG(total_area)::NUMERIC) AS avg_area_new
FROM real_estate.advertisement 
NATURAL JOIN real_estate.flats
WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' AND (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018)
GROUP BY num_month, month_name),
--Подсчитываем количество новых объявлений в каждом месяце, а также некоторые статистические показатели
new_stat AS (
SELECT 
	EXTRACT(month FROM first_day_exposition) AS num_month,
	TO_CHAR(first_day_exposition, 'TMmon') AS month_name,
	ROUND(AVG(last_price/total_area)::NUMERIC) AS avg_rub_m_sold,
	ROUND(AVG(total_area)::NUMERIC) AS avg_area_sold,
	COUNT(id) AS cnt_new
FROM real_estate.advertisement 
NATURAL JOIN real_estate.flats
WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' AND (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018)
GROUP BY num_month, month_name
)
--Соотносим номер месяца с его наименованием, присваиваем каждому месяцу ранг в зависимости от количества новых объявлений и продаж
SELECT 
	new_stat.month_name,
	RANK() OVER(ORDER BY cnt_new DESC) AS rate_new,
	cnt_new,
	ROUND(cnt_new::numeric / SUM(cnt_new) OVER() * 100) AS new_adv_percent,
	RANK() OVER(ORDER BY cnt_sold DESC) AS rate_sold,
	cnt_sold,
	ROUND(cnt_sold::numeric / SUM(cnt_new) OVER() * 100) AS sold_adv_percent,
	avg_rub_m_new,
	avg_rub_m_sold,
	avg_area_new,
	avg_area_sold
FROM sale_stat
JOIN new_stat USING(num_month)
ORDER BY num_month;
--Анализ рынка недвижимости Ленинградской области
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
 )
 --Для каждого города считаем количество объявлений, долю проданных из них, а также основные статистические показатели
 SELECT
 	city,
 	COUNT(id) AS count_adv,
 	ROUND(COUNT(days_exposition)::NUMERIC / COUNT(id), 2) AS sold_part,
 	NTILE(4) OVER(ORDER BY (AVG(days_exposition))) AS rank_avg_day_exposition,
 	ROUND(AVG(last_price/total_area)::NUMERIC) AS avg_rub_m,
	ROUND(AVG(total_area)::NUMERIC) AS avg_area,
	ROUND(AVG(days_exposition)::numeric) AS avg_sale_time,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS mediana_floors
 FROM real_estate.flats
 NATURAL JOIN real_estate.advertisement 
 JOIN real_estate.city USING(city_id)
 WHERE id IN (SELECT * FROM filtered_id) AND city_id != '6X8I' AND (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018)
 GROUP BY city
 ORDER BY count_adv DESC
 LIMIT 15;--топ-15 по количеству объявлений 


