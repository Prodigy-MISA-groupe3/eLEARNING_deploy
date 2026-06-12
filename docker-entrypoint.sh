#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# 1. Config PHP depuis les variables d'environnement
# ---------------------------------------------------------------------------
cat > /usr/local/etc/php/conf.d/moodle.ini <<EOF
memory_limit=${PHP_MEMORY_LIMIT:-256M}
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE:-100M}
post_max_size=${PHP_POST_MAX_SIZE:-100M}
max_execution_time=${PHP_MAX_EXECUTION_TIME:-300}
max_input_vars=${PHP_MAX_INPUT_VARS:-5000}
max_input_time=${PHP_MAX_INPUT_TIME:-300}
display_errors=Off
log_errors=On
error_log=/dev/stderr
EOF

cat > /usr/local/etc/php/conf.d/opcache.ini <<EOF
opcache.enable=${OPCACHE_ENABLE:-1}
opcache.memory_consumption=${OPCACHE_MEMORY:-256}
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=${OPCACHE_MAX_FILES:-20000}
opcache.validate_timestamps=${OPCACHE_VALIDATE_TIMESTAMPS:-0}
opcache.save_comments=1
EOF

# ---------------------------------------------------------------------------
# 2. Sync du code "pristine" (image) -> volume public/
#    Sans --delete : applique les MAJ du cœur tout en gardant les
#    plugins/thèmes uploadés via l'UI (qui n'existent que dans le volume).
# ---------------------------------------------------------------------------
if [ -d /opt/iomad-dist-public ]; then
    echo "[entrypoint] Sync du code public/ (cœur IOMAD) vers le volume..."
    rsync -a /opt/iomad-dist-public/ /var/www/html/public/
fi

# ---------------------------------------------------------------------------
# 3. config.php À LA RACINE (layout 5.x). public/config.php n'est qu'un shim
#    livré par le cœur qui charge ../config.php. On régénère depuis l'ENV
#    à chaque boot pour que la config (DB, wwwroot) suive l'environnement.
# ---------------------------------------------------------------------------
if [ -n "$MOODLE_DB_HOST" ]; then
    cat > /var/www/html/config.php <<PHPEOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = '${MOODLE_DB_TYPE:-pgsql}';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${MOODLE_DB_HOST}';
\$CFG->dbname    = '${MOODLE_DB_NAME:-moodle}';
\$CFG->dbuser    = '${MOODLE_DB_USER:-moodle}';
\$CFG->dbpass    = '${MOODLE_DB_PASSWORD}';
\$CFG->prefix    = '${MOODLE_DB_PREFIX:-mdl_}';
\$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport'    => '${MOODLE_DB_PORT:-5432}',
    'dbsocket'  => '',
);

\$CFG->wwwroot   = '${MOODLE_WWW_ROOT:-http://localhost}';
\$CFG->dataroot  = '/var/www/moodledata';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 02777;

// Reverse proxy (Traefik/Dokploy) - terminaison SSL en amont
\$CFG->sslproxy = ${MOODLE_SSLPROXY:-true};

// Interdit l'auto-déploiement de MAJ via l'UI en prod (sécurité / reproductibilité).
// Mettre à false en dev si tu veux pouvoir uploader des plugins via le navigateur.
\$CFG->disableupdateautodeploy = ${MOODLE_DISABLE_AUTODEPLOY:-false};

require_once(__DIR__ . '/lib/setup.php'); // charge lib/setup.php (racine)
PHPEOF
    chown www-data:www-data /var/www/html/config.php
fi

# ---------------------------------------------------------------------------
# 4. Permissions (le volume public/ doit être inscriptible par www-data
#    pour permettre l'upload de plugins via l'UI)
# ---------------------------------------------------------------------------
chown -R www-data:www-data /var/www/html/public /var/www/moodledata

# ---------------------------------------------------------------------------
# 5. Installation / mise à jour automatique de la base
# ---------------------------------------------------------------------------
if [ -n "$MOODLE_DB_HOST" ]; then

    # Attente de la disponibilité de PostgreSQL
    echo "[entrypoint] Attente de la base ${MOODLE_DB_HOST}:${MOODLE_DB_PORT:-5432}..."
    for i in $(seq 1 30); do
        if php -r '$c=@pg_connect("host=".getenv("MOODLE_DB_HOST")." port=".(getenv("MOODLE_DB_PORT")?:"5432")." dbname=".getenv("MOODLE_DB_NAME")." user=".getenv("MOODLE_DB_USER")." password=".getenv("MOODLE_DB_PASSWORD")); exit($c?0:1);' 2>/dev/null; then
            echo "[entrypoint] Base joignable."
            break
        fi
        echo "[entrypoint]   ... tentative $i/30"
        sleep 2
    done

    # La base est-elle déjà installée ? (cfg.php échoue si pas de tables Moodle)
    if runuser -u www-data -- php /var/www/html/admin/cli/cfg.php --name=version >/dev/null 2>&1; then
        echo "[entrypoint] Installation détectée -> upgrade (sync cœur + plugins)..."
        runuser -u www-data -- php /var/www/html/admin/cli/upgrade.php --non-interactive || true
    else
        if [ -n "$MOODLE_ADMIN_PASSWORD" ]; then
            echo "[entrypoint] Base vide -> installation automatique..."
            runuser -u www-data -- php /var/www/html/admin/cli/install_database.php \
                --agree-license \
                --lang="${MOODLE_LANG:-en}" \
                --adminuser="${MOODLE_ADMIN_USER:-admin}" \
                --adminpass="${MOODLE_ADMIN_PASSWORD}" \
                --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
                --fullname="${MOODLE_SITE_FULLNAME:-IOMAD eLearning}" \
                --shortname="${MOODLE_SITE_SHORTNAME:-iomad}" \
                || echo "[entrypoint] !! Echec install_database.php (voir logs ci-dessus)"
        else
            echo "[entrypoint] Base vide et MOODLE_ADMIN_PASSWORD absent -> install via le navigateur."
        fi
    fi

    runuser -u www-data -- php /var/www/html/admin/cli/purge_caches.php >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 6. Cron en arrière-plan + démarrage Apache
# ---------------------------------------------------------------------------
cron
exec "$@"
