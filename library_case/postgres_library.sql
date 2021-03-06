-- 1) Найти произведения, которые издавались более 5 раз
SELECT 
  b.title
FROM 
  edition AS e
LEFT JOIN book AS b 
  ON e.id_book = b.id
GROUP BY 
  b.title
HAVING 
  COUNT(b.title) > 5;


-- 2) Проверить, есть ли экземпляры, не привязанные к ни к одному изданию.
SELECT 
  id
FROM
  exemplar
WHERE 
  id_edition IS Null;
  
  
-- 3) Для каждого пользователя найти последние три взятые им произведения. Для 
-- каждого такого произведения указать сколько всего раз ее брали (за все время).

-- # 1) в journal для каждого юзера ранжируем взятые книги по дате(+ джойним чтобы вытащить название произведения)
-- # 2) в taken_times считаем сколько раз взята книга, и джойним счет в журнал, к-й фильтруем по посл.3м книгам
WITH journal AS (
SELECT la.id_user, la.date_taken, b.title,
  ROW_NUMBER() OVER (PARTITION BY la.id_user ORDER BY la.date_taken DESC) AS rn
FROM 
  log_action AS la
LEFT JOIN 
  exemplar AS ex 
  ON la.id_exemplar = ex.id
LEFT JOIN 
  edition AS ed 
  ON ex.id_edition = ed.id 
LEFT JOIN 
  book AS b 
  ON ed.id_book = b.id 
    ),

taken_times	AS (
SELECT 
  title, 
  COUNT(date_taken) AS times_taken 
FROM 
  journal 
GROUP BY 
  title
)

SELECT 
  j.id_user, 
  j.title, 
  t.times_taken
FROM 
  journal AS j
LEFT JOIN 
  taken_times AS t 
  ON j.title = t.title
WHERE 
  rn <= 3;
  
-- 4) Список самых неблагонадежных пользователей библиотеки – рейтинг 10 самыхсамых плохих пользователей по двум или более критериям. Критерии
-- неблагонадежности, с точки зрения бизнеса, предложите самостоятельно

-- Взял ванильный подход, рассчитывающий потенциальный ущерб от клиента, исходя из времени хранения у себя взятых книг с учетом их размера
-- # в holding собираем для каждого юзера инфу о времени хранения и объеме взятых книг (
-- # 		текущей датой считаем дату посл.возврата, + заполняем пропуски в date_returned и pages_qty)
-- # каждый юзер получает усредненые отмасштабированые(minmax) признаки времени хранения и объема книг, 
-- #			произведение которых будет "коэффициентом плохости" клиента для бизнеса. Топ 10.
WITH holding AS (
SELECT
  la.id_user,
  round(COALESCE(ed.pages_qty, AVG(ed.pages_qty) OVER())) AS pages_filled,
  COALESCE(la.date_returned, MAX(la.date_returned) OVER() + INTERVAL '1' DAY) -  la.date_taken AS days_holding
FROM 
	log_action AS la
LEFT JOIN 
	exemplar AS ex 
	ON la.id_exemplar = ex.id
LEFT JOIN 
	edition AS ed 
	ON ex.id_edition = ed.id 
),

user_features AS (
SELECT 
	id_user,
	EXTRACT(DAY FROM AVG(days_holding)) AS avg_holding,
	round(AVG(pages_filled)) AS avg_pages
FROM 
	holding 
GROUP BY 
	id_user
),

features_scaled AS (
SELECT 
	id_user, 
	(avg_holding - MIN(avg_holding) OVER()) / (MAX(avg_holding) OVER() - MIN(avg_holding) OVER()) AS avg_holding_normed,
	(avg_pages - MIN(avg_pages) OVER()) / (MAX(avg_pages) OVER() - MIN(avg_pages) OVER()) AS avg_pages_normed
FROM 
  user_features
)
	
SELECT 
  id_user, 
	round(avg_holding_normed * avg_pages_normed, 3) AS unreliable_coef
FROM 
  features_scaled
ORDER BY 
  unreliable_coef DESC
LIMIT 10
