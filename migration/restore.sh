#!/usr/bin/env bash
# =========================================================================
# Restauration d'une instance IOMAD sur un NOUVEAU serveur.
#
# Pré-requis sur la cible :
#   1. eLEARNING_deploy/.env configuré (DB externe accessible et VIDE)
#   2. les volumes créés :  (depuis eLEARNING_deploy) docker compose create
#
# Usage :  ./migration/restore.sh migration/backup/AAAAMMJJ-HHMMSS
# =========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-${SCRIPT_DIR}/..}"
[ -f "${PROJECT_DIR}/.env" ] && set -a && . "${PROJECT_DIR}/.env" && set +a

SRC="${1:?Usage: ./migration/restore.sh <dossier-backup>}"
SRC="$(cd "$SRC" && pwd)"
PREFIX="${VOLUME_PREFIX:-elearning_deploy}"
NET="${DOKPLOY_NETWORK:-dokploy-network}"

[ -f "${SRC}/db.sql.gz" ] || { echo "Introuvable: ${SRC}/db.sql.gz"; exit 1; }

echo ">> Restore PostgreSQL -> ${MOODLE_DB_HOST}/${MOODLE_DB_NAME} (base cible vide)"
gunzip -c "${SRC}/db.sql.gz" | docker run --rm -i --network "$NET" \
    -e PGPASSWORD="$MOODLE_DB_PASSWORD" postgres:16-alpine \
    psql -h "$MOODLE_DB_HOST" -p "${MOODLE_DB_PORT:-5432}" \
         -U "$MOODLE_DB_USER" -d "$MOODLE_DB_NAME"

echo ">> Restore moodledata... (uid 33 = www-data)"
docker run --rm -v "${PREFIX}_moodledata:/data" -v "${SRC}:/backup:ro" alpine \
    sh -c "tar xzf /backup/moodledata.tar.gz -C /data && chown -R 33:33 /data"

if [ -f "${SRC}/public.tar.gz" ]; then
    echo ">> Restore public (thèmes/plugins uploadés)..."
    docker run --rm -v "${PREFIX}_iomad_public:/data" -v "${SRC}:/backup:ro" alpine \
        sh -c "tar xzf /backup/public.tar.gz -C /data && chown -R 33:33 /data"
fi

echo ">> OK. Démarre l'app :  (depuis eLEARNING_deploy) docker compose up -d --build"
echo "   L'entrypoint lancera upgrade.php + purge_caches automatiquement."
