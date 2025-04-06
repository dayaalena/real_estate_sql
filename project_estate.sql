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
 		ELSE 'более полугода'
 	END AS sale_time,
 	last_price / total_area AS rub_kv_m,
 	last_price
 	FROM real_estate.flats
 	NATURAL JOIN real_estate.advertisement
	WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'
 )   
--Группируем объявления по локации и времени продажи, подсчитываем основные статистические показатели
SELECT 
	location, 
	sale_time, 
	ROUND(AVG(rub_kv_m)::NUMERIC, 5) AS avg_cost_per_meter,
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS mediana_floors
FROM category_data
GROUP BY location, sale_time
ORDER BY LOCATION DESC, AVG(days_exposition);
--Сезонность объявлений
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
	EXTRACT(month FROM COALESCE(first_day_exposition::date + INTERVAL '1 days' * days_exposition, first_day_exposition)) AS num_month,
	COUNT(id) AS cnt_sold
FROM real_estate.advertisement 
NATURAL JOIN real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY num_month),
--Подсчитываем количество новых объявлений в каждом месяце, а также некоторые статистические показатели
new_stat AS (
SELECT 
	EXTRACT(month FROM first_day_exposition) AS num_month,
	ROUND(AVG(last_price/total_area)::NUMERIC, 2) AS avg_rub_m,
	ROUND(AVG(total_area)::NUMERIC, 3) AS avg_area,
	COUNT(id) AS cnt_new
FROM real_estate.advertisement 
NATURAL JOIN real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY num_month
)
--Соотносим номер месяца с его наименованием, присваиваем каждому месяцу ранг в зависимости от количества новых объявлений и продаж
SELECT 
	CASE
		WHEN num_month = 1 THEN 'Январь'
		WHEN num_month = 2 THEN 'Февраль'
		WHEN num_month = 3 THEN 'Март'
		WHEN num_month = 4 THEN 'Апрель'
		WHEN num_month = 5 THEN 'Май'
		WHEN num_month = 6 THEN 'Июнь'
		WHEN num_month = 7 THEN 'Июль'
		WHEN num_month = 8 THEN 'Август'
		WHEN num_month = 9 THEN 'Сентябрь'
		WHEN num_month = 10 THEN 'Октябрь'
		WHEN num_month = 11 THEN 'Ноябрь'
		ELSE 'Декабрь'
	END AS month,
	RANK() OVER(ORDER BY cnt_sold DESC, cnt_new DESC) AS rate,
	cnt_sold,
	cnt_new,
	avg_rub_m,
	avg_area
FROM sale_stat
NATURAL JOIN new_stat 
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
 ),
 --Подсчитываем количество проданных квартир в каждом населённом пункте
 sold_city AS(
 SELECT
	city_id,
	COUNT(id) AS count_adv
 FROM real_estate.flats
 NATURAL JOIN real_estate.advertisement 
 WHERE id IN (SELECT * FROM filtered_id) AND first_day_exposition + days_exposition * interval '1 day' <= '2019-05-03'
 GROUP BY city_id
 ORDER BY count_adv DESC)
 --Для каждого города считаем количество объявлений, долю проданных из них, а также основные статистические показатели
 SELECT
 	city,
 	COUNT(id) AS count_adv,
 	ROUND(count_adv::NUMERIC / COUNT(id), 4) AS sold_part,
 	ROUND(AVG(last_price/total_area)::NUMERIC, 2) AS avg_rub_m,
	ROUND(AVG(total_area)::NUMERIC, 3) AS avg_area,
	ROUND(AVG(days_exposition)::numeric,2) AS avg_sale_time,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS mediana_floors
 FROM real_estate.flats
 NATURAL JOIN real_estate.advertisement 
 JOIN sold_city USING(city_id)
 JOIN real_estate.city USING(city_id)
 WHERE id IN (SELECT * FROM filtered_id)
 GROUP BY city, count_adv
 ORDER BY count_adv DESC
 LIMIT 15;--топ-15о количеству объявлений 

