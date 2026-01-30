-- On supprime les tables inutiles ou en doublon pour y voir clair
DROP TABLE IF EXISTS dvf_aggregated_db;
DROP TABLE IF EXISTS dvf_bpe_joined;
DROP TABLE IF EXISTS final_market_analysis; -- Au cas où elle traîne
 
DROP TABLE IF EXISTS final_market_analysis;

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

-- Le test ultime
SELECT * FROM final_market_analysis LIMIT 10;

SELECT * FROM final_market_analysis;