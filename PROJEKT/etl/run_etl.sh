#!/usr/bin/env bash
# ============================================================================
# Skrypt uruchamiający moduł ETL lokalnie na hoście
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Tworzenie wirtualnego środowiska jeśli nie istnieje
if [ ! -d "venv" ]; then
    echo "[*] Tworzenie środowiska wirtualnego venv..."
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt
fi

echo "[*] Uruchamianie ETL Data Loader..."
./venv/bin/python etl_loader.py "$@"
