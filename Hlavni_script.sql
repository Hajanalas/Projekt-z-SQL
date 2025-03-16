
-- VÝZKUMNÉ OTÁZKY:

/* 1) Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají? */

/* Nejprve si z primární tabulky vytvořím pomocné view, přes které budu následně snáze filtrovat potřebné informace. 
 * Zejména si takto do filtrovaných výsledků přidám sloupec s průměrným ročním platem za předchozí období 
 * a také procentuální meziroční nárůst průměrných mezd */

CREATE OR REPLACE VIEW v_question01 AS
SELECT 
	`year`,
	industry_branch,
	avg_annual_branch_salary,
	previous_avg_an_br_salary,
	ROUND((((avg_annual_branch_salary -  previous_avg_an_br_salary) / previous_avg_an_br_salary) * 100), 2) AS percentage_increase
FROM(SELECT 
		`year`, 
		industry_branch,
		avg(quarter_salary) AS avg_annual_branch_salary,
		LAG(avg(quarter_salary)) OVER (PARTITION BY industry_branch ORDER BY `year`) AS previous_avg_an_br_salary
	FROM(SELECT
			`year`, 
			industry_branch,
			avg(avg_salary) AS quarter_salary
		FROM t_jana_halasova_project_SQL_primary_final
		GROUP BY industry_branch, `year`, payroll_quarter) AS help_t1
	GROUP BY industry_branch, `year`
	ORDER BY industry_branch) AS help_t2;


-- Poté zjistím, v jakém odvětví došlo k nejvyššímu a nejnižšímu nárůstu mezd v rámci sledovaného období

WITH avg_salary_2006 AS (
	SELECT 
		`year`,
		industry_branch,
		avg_annual_branch_salary AS avg_salary_2006
	FROM v_question01 vq 
	WHERE `year` = 2006),
avg_salary_2018 AS (
	SELECT 
		`year`,
		industry_branch,
		avg_annual_branch_salary AS avg_salary_2018
	FROM v_question01 vq 
	WHERE `year` = 2018)
SELECT 
	as06.industry_branch,
	avg_salary_2006,
	avg_salary_2018,
	ROUND( (((avg_salary_2018 - avg_salary_2006) / avg_salary_2006) * 100), 2) AS percentage_increase
FROM avg_salary_2006 as06
JOIN avg_salary_2018 as18
	ON as06.industry_branch = as18.industry_branch
ORDER BY percentage_increase DESC;


-- Dále vyfiltruji roky a odvětví, v nichž došlo k největšímu nárůstu mezd

SELECT *
FROM v_question01
ORDER BY percentage_increase DESC;


-- Nakonec vyfiltruji roky a odvětví, v nichž došlo k poklesu průměrných ročních mezd

SELECT *
FROM v_question01
WHERE percentage_increase < 0
ORDER BY percentage_increase ASC;



/* 2) Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd? */

/* Vytvořím si opět pomocné view, kdy si z primární tabulky vyfiltruji pouze informace o cenách 
 * mléka a chleba a o průměrných mzdách za jednotlivá čtvrtletí v letech 2006 a 2018 */

CREATE OR REPLACE VIEW v_question02 AS
WITH help_t1 AS (
	SELECT * 
	FROM t_jana_halasova_project_SQL_primary_final
	WHERE `year`IN (2006, 2018) 
		AND price_category_name IN ("Mléko polotučné pasterované", "Chléb konzumní kmínový")),
help_t2 AS (
	SELECT
		`year` AS t2_year, 
		industry_branch AS t2_industry_branch,
		avg(avg_salary) AS quarter_salary
	FROM t_jana_halasova_project_SQL_primary_final
	GROUP BY `year`, payroll_quarter)
SELECT * 
FROM help_t1
LEFT JOIN help_t2
	ON help_t1.`year` = help_t2.t2_year;


-- Z tohoto view následně vyfiltruji průměrný plat v daném roce, cenu sledovaných potravin a současně i kupní sílu ve vztahu k těmto potravinám

SELECT
	`year`,
	price_category_name,
	ROUND(avg(quarter_salary), 2) AS annual_avg_salary,
	REPLACE(CONCAT((ROUND(avg(vq02.price), 2)), 'Kč / ', cpc.price_value, cpc.price_unit), '.', ',') AS price,
	ROUND((ROUND(avg(quarter_salary), 2)) / (ROUND(avg(vq02.price), 2)), 2) AS purchasing_power	
FROM v_question02 vq02
LEFT JOIN czechia_price_category cpc 
	ON vq02.price_category_code = cpc.code
GROUP BY `year`, price_category_name;



/* 3) Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)? */

/* Nejprve vytvořím pomocné view, kdy si vypočítám průměrné ceny potravin v každé sledované kategorii v příslušném roce 
* a zároveň si do výpisu přidám sloupec s průměrnými cenami potravin v předchozím roce */

CREATE OR REPLACE VIEW v_question03 AS
SELECT 
	`year`,
	price_category_name,
	ROUND(avg(price), 2) AS avg_price,
	ROUND(LAG(avg(price), 1) OVER (PARTITION BY price_category_name ORDER BY year), 2) AS previous_avg_price
FROM t_jana_halasova_project_SQL_primary_final
GROUP BY price_category_name, `year`;


-- Dále si vypočítám průměrný roční nárůst cen potravin mezi lety 2006 až 2018

WITH annual_price_increase AS (
	SELECT
		price_category_name,
		`year`,
		avg_price,
		previous_avg_price,
		ROUND((((avg_price - previous_avg_price) / previous_avg_price) * 100), 2) AS pct_annual_increase
	FROM v_question03
	ORDER BY price_category_name, `year`
)
SELECT 
	price_category_name,
	ROUND(avg(pct_annual_increase), 2) AS avg_annual_increase_btw_2006_and_2018
FROM annual_price_increase
GROUP BY price_category_name
ORDER BY avg(pct_annual_increase);


-- Zjistím si i celkový nárůst cen potravin za období 2006 až 2018

CREATE OR REPLACE VIEW v_total_price_increase AS
WITH avg_price_2006 AS (
	SELECT 
		`year`,
		price_category_name,
		avg_price
	FROM v_question03 vq
	WHERE `year` = 2006
),
avg_price_2018 AS (
	SELECT 
		`year`,
		price_category_name,
		avg_price
	FROM v_question03 vq
	WHERE `year` = 2018
)
SELECT
	avg_price_2006.price_category_name,
	avg_price_2006.avg_price AS avg_price_2006,
	avg_price_2018.avg_price AS avg_price_2018,
	ROUND((((avg_price_2018.avg_price - avg_price_2006.avg_price) / avg_price_2006.avg_price) * 100), 2) AS total_increase
FROM avg_price_2006
JOIN avg_price_2018
	ON avg_price_2018.price_category_name = avg_price_2006.price_category_name
GROUP BY price_category_name
ORDER BY total_increase DESC;


/* Z tohoto VIEW je nicméně zřejmé, že jsem získala pouze 26 záznamů, i když sledovaných kategorií potravin je 27. 
 * Ve view mi chybí kategorie "Jakostní víno bílé". Tato kategorie je sledována az od června roku 2015, jak vyplává z následujících dotazů */

SELECT DISTINCT price_category_name
FROM t_jana_halasova_project_SQL_primary_final
EXCEPT
SELECT DISTINCT price_category_name 
FROM v_total_price_increase;

SELECT *
FROM t_jana_halasova_project_SQL_primary_final
WHERE price_category_name = 'Jakostní víno bílé'
ORDER BY date_from;


-- Meziroční nárůst ceny u kategorie "Jakostní víno bílé":

SELECT *,
	ROUND((((avg_price - previous_avg_price) / previous_avg_price) * 100), 2) AS pct_annual_increase
FROM v_question03 vq
WHERE price_category_name = 'Jakostní víno bílé';


-- A celkový nárůst ceny u kategorie "Jakostní víno bílé" za období 2015 až 2018:

CREATE OR REPLACE VIEW v_wine_total_price_increase AS
WITH price_of_wine AS (
	SELECT 
		vq.`year`,
		price_category_name,
		avg_price
	FROM v_question03 vq 
	WHERE price_category_name = 'Jakostní víno bílé' 
		AND vq.`year` IN (2015, 2018)
),
price_of_wine_2 AS (
	SELECT
		`year`,
		price_category_name,
		avg_price,
		ROUND(LAG(avg_price, 1) OVER (ORDER BY year), 2) AS avg_price_2015
	FROM price_of_wine
)
SELECT 
	`year`,
	price_category_name,
	avg_price AS avg_price_2018,
	avg_price_2015,
	ROUND((((avg_price - avg_price_2015) / avg_price_2015) * 100), 2) AS total_increase
FROM price_of_wine_2
WHERE `year` = 2018;


-- Následně propojím view s calkovým nárůstem cen potravin s view se záznamy o kategorii "Jakostní víno bílé"

SELECT *
FROM (
	SELECT 
		price_category_name,
		total_increase
	FROM v_total_price_increase
	UNION
	SELECT
		price_category_name,
		total_increase
	FROM v_wine_total_price_increase) AS complete_total_price_increase
ORDER BY total_increase DESC;



/* 4) Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)? */

/* Nejprve si vytvořím view, ve kterém si zobrazím, o kolik procent vzrostly každoročně ceny potravin průměrně ve všech kategoriích dohromady. 
 * Zjistím si tedy nejdříve každoroční nárůst cen potravin v jednotlivých kategoriích a z této hodnoty vypočítám průměr. */

CREATE OR REPLACE VIEW v_price_increase AS
WITH price_increase AS (
	SELECT 
		`year`,
		price_category_name,
		ROUND(avg(price), 2) AS avg_price,
		ROUND(LAG(avg(price), 1) OVER (PARTITION BY price_category_name ORDER BY `year`), 2) AS previous_avg_price
	FROM t_jana_halasova_project_SQL_primary_final
	GROUP BY price_category_name, `year`
),
annual_price_increase_for_categories AS (
	SELECT *,
		ROUND((((avg_price - previous_avg_price) / previous_avg_price) * 100), 2) AS pct_annual_increase
	FROM price_increase
)
SELECT 
	`year`,
	ROUND(avg(pct_annual_increase), 2) AS pct_avg_annual_price_increase
FROM annual_price_increase_for_categories 
GROUP BY `year`;

SELECT *
FROM v_price_increase
ORDER BY pct_avg_annual_price_increase DESC;


/* Dále si vytvořím view s průměrným procentuálním nárůstem platů ve všech odvětvích dohromady.
 * K tomu využiji již vytvořené view 'v_question01' (vytvořeno v rámci první výzkumné otázky). */

CREATE OR REPLACE VIEW v_salary_increase AS
SELECT 
	`year`,
	ROUND(avg(avg_annual_branch_salary), 2) AS avg_an_salary,
	ROUND(avg(previous_avg_an_br_salary), 2) AS previous_avg_an_salary,
	ROUND(avg(percentage_increase), 2) AS pct_avg_annual_salary_increase
FROM v_question01
GROUP BY `year`;


-- Nakonec toto view pro porovnání spojím s výše vytvořeným view s ročním nárůstem cen potravin.

SELECT 
	vpi.`year`,
	pct_avg_annual_price_increase,
	pct_avg_annual_salary_increase,
	(pct_avg_annual_price_increase - pct_avg_annual_salary_increase) AS pct_difference
FROM v_price_increase vpi 
LEFT JOIN v_salary_increase vsi
	ON vpi.`year` = vsi.`year`
ORDER BY pct_difference DESC;



/* 5) Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, 
projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem? */

/* Meziroční nárůst cen potravin v jednotlivých letech je zachycen v již vytvořeném view v_price_increase 
a meziroční nárůst mezd ve view v_salary_increase. Vytvořím si tedy view s meziročním nárůstem HDP a vše porovnám.  */

CREATE OR REPLACE VIEW v_GDP_increase AS
WITH GDP_cz AS (
	SELECT 
		country,
		`year`,
		GDP
	FROM t_jana_halasova_project_SQL_secondary_final 
	WHERE country = 'Czech Republic'
),
GDP_cz_previous_year AS (
	SELECT 
		country,
		`year`,
		GDP,
		LAG(GDP) OVER (ORDER BY `year`) AS previous_GDP
	FROM GDP_cz
)
SELECT
	country,
	`year`,
	GDP,
	previous_GDP,
	ROUND((((GDP - previous_GDP) / previous_GDP) * 100), 2) AS GDP_increase
FROM GDP_cz_previous_year;

SELECT *
FROM v_GDP_increase;

SELECT 
	vpi.`year`,
	vpi.pct_avg_annual_price_increase,
	vsi.pct_avg_annual_salary_increase,
	vgi.GDP_increase
FROM v_price_increase vpi 
LEFT JOIN v_salary_increase vsi
	ON vpi.`year` = vsi.`year`
LEFT JOIN v_GDP_increase vgi
	ON vpi.`year` = vgi.`year`
WHERE vpi.`year` >= 2007 AND vpi.`year` <= 2018;