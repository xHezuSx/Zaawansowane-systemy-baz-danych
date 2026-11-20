import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
ENV_FILE = PROJECT_DIR / ".env"

# Bezpieczne ładowanie .env (z python-dotenv lub fallback na czysty Python)
try:
    from dotenv import load_dotenv
    if ENV_FILE.exists():
        load_dotenv(ENV_FILE)
    else:
        load_dotenv()
except ImportError:
    if ENV_FILE.exists():
        with open(ENV_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())

# Parametry połączenia z bazą Oracle
ORACLE_HOST = os.getenv("ORACLE_HOST", "localhost")
ORACLE_PORT = int(os.getenv("ORACLE_PORT", "1521"))
ORACLE_SERVICE_NAME = os.getenv("ORACLE_SERVICE_NAME", os.getenv("ORACLE_PDB", "FREEPDB1"))
ORACLE_USER = os.getenv("ORACLE_USER", os.getenv("ORACLE_APP_USER", "his_admin"))
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", os.getenv("ORACLE_APP_PASSWORD", "HisPassword123!"))

# Ścieżki katalogów danych ETL
DATA_DIR = BASE_DIR / "data"
INBOX_DIR = DATA_DIR / "inbox"
PROCESSED_DIR = DATA_DIR / "processed"
FAILED_DIR = DATA_DIR / "failed"

# Upewnienie się, że katalogi istnieją
INBOX_DIR.mkdir(parents=True, exist_ok=True)
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
FAILED_DIR.mkdir(parents=True, exist_ok=True)
