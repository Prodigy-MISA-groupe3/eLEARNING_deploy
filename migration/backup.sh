#!/usr/bin/env bash
# =========================================================================
# Sauvegarde complète d'une instance IOMAD (eLEARNING_deploy) pour migration.
# Vit dans le repo, sous migration/.
#
# Produit 1 dossier horodaté dans migration/backup/ contenant :
#   - db.sql.gz          (dump PostgreSQL)
#   - moodledata.tar.gz  (fichiers users, caches exclus)
#   - public.tar.gz      (thèmes + plugins uploadés via l'UI)
#
# Usage :  ./migration/backup.sh
# =========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-${SCRIPT_DIR}/..}"
[ -f "${PROJECT_DIR}/.env" ] && set -a && . "${PROJECT_DIR}/.env" && set +a

PREFIX="${VOLUME_PREFIX:-elearning_deploy}"
NET="${DOKPLOY_NETWORK:-dokploy-network}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${SCRIPT_DIR}/backup/${STAMP}"
mkdir -p "$OUT"

echo ">> Dump PostgreSQL (${MOODLE_DB_HOST}/${MOODLE_DB_NAME})..."
docker run --rm --network "$NET" -e PGPASSWORD="$MOODLE_DB_PASSWORD" postgres:16-alpine \
    pg_dump -h "$MOODLE_DB_HOST" -p "${MOODLE_DB_PORT:-5432}" \
            -U "$MOODLE_DB_USER" -d "$MOODLE_DB_NAME" --no-owner --no-privileges \
    | gzip > "${OUT}/db.sql.gz"

echo ">> Archive moodledata (caches exclus)..."
docker run --rm -v "${PREFIX}_moodledata:/data:ro" -v "${OUT}:/backup" alpine \
    tar czf /backup/moodledata.tar.gz -C /data \
        --exclude=./cache --exclude=./localcache --exclude=./sessions \
        --exclude=./temp --exclude=./trashdir .

echo ">> Archive public (thèmes + plugins uploadés)..."
docker run --rm -v "${PREFIX}_iomad_public:/data:ro" -v "${OUT}:/backup" alpine \
    tar czf /backup/public.tar.gz -C /data .

echo ">> OK -> ${OUT}"
ls -lh "$OUT"
