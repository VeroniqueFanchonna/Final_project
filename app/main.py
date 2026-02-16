import os
import logging
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security.api_key import APIKeyHeader
from sqlalchemy import create_engine, text
import pandas as pd
from starlette.status import HTTP_403_FORBIDDEN

# ============================================================================
# CONFIGURATION LOGGING (utile pour déboguer les erreurs 500)
# ============================================================================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 1. Load environment variables / Charger les variables d'environnement
load_dotenv()  # Assure que les variables du fichier .env sont chargées dans os.environ


# 2. Initialize FastAPI / Initialiser l'application FastAPI
app = FastAPI(
    title="API Decision-Support : Immobilier VS Indicateurs Socio-Économiques Communaux",
    description="Interface d'accès aux scores d'attractivité et données DVF enrichies (Projet Certification RNCP)",
    version="1.0.0"
)

# 3. Database connection / Configuration de la connexion SQL
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME")

# ============================================================================
# VALIDATION DES VARIABLES D'ENVIRONNEMENT
# ============================================================================
if not all([DB_USER, DB_PASS, DB_HOST, DB_NAME]):
    logger.error("❌ Variables d'environnement manquantes. Vérifiez votre .env")
    raise ValueError("Variables d'environnement incomplètes (DB_USER, DB_PASSWORD, DB_HOST, DB_NAME)")

# Create the connection string / Créer la chaîne de connexion
# On utilise le connecteur officiel 'mysqlconnector' avec UTF-8
DATABASE_URL = f"mysql+mysqlconnector://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}?charset=utf8mb4"

# Configure l'engine pour éviter les erreurs de connexion
engine = create_engine(
    DATABASE_URL,
    connect_args={
        'auth_plugin': 'mysql_native_password',
        'use_pure': True,
        'client_flags': [2048],
        'charset': 'utf8mb4'  # Support des accents français
    },
    pool_pre_ping=True,  # Vérifie la connexion avant chaque requête
    echo=False  # Mettez à True pour déboguer les requêtes SQL
)

logger.info("✅ Engine SQLAlchemy configuré avec succès")

# 4. Security Configuration / Configuration de la sécurité (C5)
API_KEY = os.getenv("MY_API_KEY")
API_KEY_NAME = "access_token"

if not API_KEY:
    logger.warning("⚠️  MY_API_KEY non définie dans .env. L'API sera accessible sans clé.")
    api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)
else:
    api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

async def get_api_key(header_value: str = Security(api_key_header)):
    """Check if the provided key matches our secret / Vérifie la clé API"""
    if not API_KEY:
        return None  # Pas de vérification si pas de clé définie
    
    if header_value == API_KEY:
        return header_value
    
    logger.warning(f"❌ Tentative d'accès avec clé invalide")
    raise HTTPException(
        status_code=HTTP_403_FORBIDDEN,
        detail="Accès refusé : Clé API invalide"
    )

# 5. Health Check Endpoint / Test de connexion DB
@app.get("/health")
def health_check():
    """Vérifier que l'API et la base de données sont opérationnelles"""
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            logger.info("✅ Connexion DB OK")
        return {"status": "OK", "database": "connected"}
    except Exception as e:
        logger.error(f"❌ Erreur de connexion DB: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Erreur DB: {str(e)}")

# 6. Main Route / La route principale
@app.get("/commune/{insee_code}", dependencies=[Depends(get_api_key)])
def get_scoring(insee_code: str):
    """
    Fetch scoring data for a specific city / Récupère les scores d'une ville
    
    Paramètres:
    - insee_code: Code INSEE de la commune (ex: "75056" pour Paris)
    
    Retourne: Dictionnaire avec tous les scores et données de la commune
    """
    # ✅ CORRECTION 1 : Utiliser 'insee_code' au lieu de 'code_insee'
    query = text("""
        SELECT * FROM final_market_predictive 
        WHERE insee_code = :insee_code
        LIMIT 1
    """)
    
    try:
        logger.info(f"🔍 Requête pour INSEE: {insee_code}")
        
        with engine.connect() as connection:
            # ✅ CORRECTION 2 : Passer le paramètre avec le bon nom
            df = pd.read_sql(query, connection, params={"insee_code": insee_code})
        
        if df.empty:
            logger.warning(f"⚠️  Code INSEE {insee_code} non trouvé")
            raise HTTPException(
                status_code=404,
                detail=f"Code INSEE '{insee_code}' non trouvé dans la base"
            )
        
        # Convertir en dictionnaire avec gestion des NaN
        result = df.iloc[0].to_dict()
        
        # Remplacer les NaN par None pour le JSON
        result = {k: (None if pd.isna(v) else v) for k, v in result.items()}
        
        logger.info(f"✅ Données retournées pour {insee_code}")
        return result
        
    except HTTPException:
        raise  # Relancer les HTTPException (404, etc.)
    except Exception as e:
        logger.error(f"❌ Erreur SQL pour {insee_code}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Erreur serveur: {str(e)}"
        )

# 7. Optional: List all communes / Optionnel : Lister les communes
@app.get("/communes/list/all", dependencies=[Depends(get_api_key)])
def list_communes(limit: int = 100):
    """Liste les communes disponibles (limité à 100 par défaut)"""
    query = text("""
        SELECT insee_code, commune, median_price_m2, median_income 
        FROM final_market_predictive 
        LIMIT :limit
    """)
    
    try:
        with engine.connect() as connection:
            df = pd.read_sql(query, connection, params={"limit": limit})
        
        return {"count": len(df), "communes": df.to_dict(orient="records")}
    except Exception as e:
        logger.error(f"❌ Erreur lors de la liste: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# 8. Run the server / Lancer le serveur
if __name__ == "__main__":
    import uvicorn
    # À adapter selon vos besoins (host, port, etc.)
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
