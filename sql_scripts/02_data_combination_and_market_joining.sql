-- On supprime les tables inutiles ou en doublon pour y voir clair
DROP TABLE IF EXISTS dvf_aggregated_db;
DROP TABLE IF exists dim_geo_cities;
DROP TABLE IF EXISTS dvf_bpe_joined;
DROP TABLE IF EXISTS final_market_analysis;  
DROP TABLE IF EXISTS final_market_predictive;
DROP TABLE IF EXISTS final_market_predictive;


CREATE TABLE final_market_analysis AS 
SELECT 
    d.*, 
    b.Admin_Services,
    b.Commerce_Proximite,
    b.Divers_Other,
    b.Education,
    b.Emploi_Employment,
    b.Grandes_Surfaces,
    b.Practical_Services,
    b.Sante_Health,
    b.Social_Services,
    b.Transport,
    b.total_services
FROM dvf_final_db d
INNER JOIN bpe_commune_db b ON d.insee_code = b.insee_code;

---------------------------------------------------------
-- SECTION 2 : INTEGRATION SOCIO-ÉCONOMIQUE (INSEE)
-- Goal: Join real estate data with cleaned income data
-- Data Enrichment for Predictive Modeling : 
-- To move from descriptive analysis to predictive modeling, we are creating a new consolidated table: `final_market_predictive`.
-- Merge the existing market data with the cleaned socio-economic indicators (Median Income)
-- Technical Choice: 
-- We use an `INNER JOIN` to ensure that every record used for Machine Learning has a complete profile. 
-- By creating a separate table, we preserve the integrity of our initial data while building a dedicated dataset for the algorithm.
---------------------------------------------------------

-- Machine learning table
DESCRIBE gps_db;
SHOW COLUMNS FROM final_market_analysis;
---------------------------------------------------------
-- CLEANING IN ORDER TO HAVE RELIABLES DATAS
-- Goal: RECREATE the previous table adding a new parameter "the reliability" computed on the 01_market... 
---------------------------------------------------------

CREATE TABLE final_market_predictive AS
SELECT 
    m.*, 
    i.nb_households,
    i.nb_inhabitants, 
    i.median_income 
FROM final_market_analysis m 
INNER JOIN income_db i ON m.insee_code = i.insee_code
WHERE m.reliability = 'High';
SHOW COLUMNS FROM final_market_predictive;

-- Vérification immédiate pour le Notebook
SELECT count(*) as total_rows_for_ml FROM final_market_predictive;
SHOW COLUMNS FROM final_market_predictive;

SELECT insee_code, median_price_m2, median_income, nb_inhabitants, reliability
FROM final_market_predictive
WHERE median_price_m2 > 0
ORDER BY median_price_m2 ASC, median_income DESC
LIMIT 10;

----
-- NOTE : 8727 rows / 21k municipalitues remain
-- Enought to ensure the robustness of our predictive model : 
-- excluding municipalities with a "Low Reliability" index (fewer than 5 real transactions), making their average price per m² statistically unstable.
-- Focusing on high-reliability data prevents outliers from distorting our future predictions
----

SELECT 
    reliability, 
    COUNT(*) as nb_communes, 
    AVG(median_price_m2) as avg_price 
FROM final_market_predictive
GROUP BY reliability;
-- remaining 25% of the db

SELECT insee_code, median_price_m2, median_income, nb_inhabitants
FROM final_market_predictive
ORDER BY median_price_m2 ASC, median_income DESC
LIMIT 10;
-- identification of areas with average incomes and low prices

SELECT 
    CASE 
        WHEN median_income < 22000 THEN '1. Économique'
        WHEN median_income BETWEEN 22000 AND 28000 THEN '2. Standard'
        ELSE '3. Premium'
    END AS category,
    COUNT(*) as nb_cities,
    ROUND(AVG(median_price_m2), 2) as avg_price
FROM final_market_predictive
GROUP BY category;
-- Average price by income level

SELECT LEFT(insee_code, 2) AS dept, 
       ROUND(AVG(median_price_m2), 2) as avg_price,
       ROUND(AVG(median_income), 0) as avg_income
FROM final_market_predictive
GROUP BY dept
ORDER BY avg_price ASC
LIMIT 5;
-- Top 5 departement for tiny

SELECT 
    COUNT(*) as final_count,
    MIN(median_price_m2) as min_price,
    MAX(median_price_m2) as max_price,
    AVG(median_income) as global_avg_income
FROM final_market_predictive;
-- mix / max median price compare to avarage income


SELECT ROUND(nb_inhabitants, -3) as pop_bracket, -- arrondit au millier
       AVG(median_price_m2) as avg_price
FROM final_market_predictive
GROUP BY pop_bracket
ORDER BY pop_bracket ASC;
-- Showing the correllation between the population density and the price


SELECT commune, 
       (median_income / median_price_m2) * (nb_inhabitants / 1000) AS potential_score
FROM final_market_predictive
ORDER BY potential_score DESC
LIMIT 10;
-- Showing the tiny house score : The higher the income and the lower the price of land, the larger this figure is


---------------------------------------------------------
-- DASHBOARD


-- DROP TABLE IF EXISTS tableau_market_predictive;
-- CREATE TABLE tableau_market_predictive AS
-- SELECT 
--     o.*,            
--     g.latitude,     
--     g.longitude
-- FROM ml_outcome_db o
-- LEFT JOIN gps_db g ON o.insee_code = g.insee_code;
    
--  DROP TABLE IF EXISTS tableau_market_predictive;

--  CREATE TABLE tableau_market_predictive AS
--  SELECT 
--     o.*, 
--     g.latitude, 
--     g.longitude
-- FROM ml_outcome_db o
-- LEFT JOIN gps_db g ON LPAD(CAST(o.insee_code AS CHAR), 5, '0') = LPAD(CAST(g.insee_code AS CHAR), 5, '0');

-- SELECT COUNT(*) FROM tableau_market_predictive WHERE latitude IS NOT NULL; 

-- "Join" issus because of differents formats of insee_code from gps or ml_outcome. Back to python
