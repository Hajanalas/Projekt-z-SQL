
-- Vytvoření sekundární tabulky s dodatečnými daty o evropských státech:

CREATE OR REPLACE TABLE t_jana_halasova_project_SQL_secondary_final AS
WITH europe_countries AS (
	SELECT 
		country,
		continent
	FROM countries
	WHERE continent = 'Europe'
)
SELECT 
	e.country, 
	ec.continent,
	`year`,
	gini,
	GDP,
	population
FROM economies e
JOIN europe_countries ec 
	ON e.country = ec.country
WHERE continent IS NOT NULL
ORDER BY `year`, country;



