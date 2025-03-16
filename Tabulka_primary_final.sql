
-- Vytvoření primární tabulky obsahující data o mzdách a cenách potravin
-- za Českou republiku:

CREATE OR REPLACE TABLE t_jana_halasova_project_SQL_primary_final AS
SELECT 
	cpay.industry_branch_code AS industry_branch_code,
	cpay.payroll_year AS year,
	cpay.payroll_quarter AS payroll_quarter,
	cpay.value AS avg_salary,
	cpib.name AS industry_branch,
	cpc.name AS price_category_name,
	cp.category_code AS price_category_code,
	cp.value AS price,
	date_format(cp.date_from, '%d. %m. %Y', 'cs_CZ') AS date_from,
	date_format(cp.date_to, '%d. %m. %Y') AS date_to
FROM czechia_price cp 
JOIN czechia_payroll cpay
	ON year(cp.date_from) = cpay.payroll_year 
LEFT JOIN czechia_payroll_industry_branch cpib
	ON cpay.industry_branch_code = cpib.code
JOIN czechia_price_category cpc 
	ON cp.category_code = cpc.code
WHERE cpay.value_type_code = 5958 
	AND cpay.calculation_code = 200
	AND cpay.industry_branch_code IS NOT NULL
	AND cp.region_code IS NULL;



