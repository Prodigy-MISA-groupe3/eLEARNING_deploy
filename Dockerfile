FROM php:8.3-apache

# Dépendances système (rsync = sync du code vers le volume au boot)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    unzip git curl cron rsync \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libxml2-dev \
    libpq-dev \
    libonig-dev \
    libsodium-dev \
    libcurl4-openssl-dev \
    pkg-config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Extensions PHP (toutes celles requises par composer.json d'IOMAD)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install \
    pdo pdo_pgsql pgsql \
    zip gd intl soap exif \
    mbstring curl sodium \
    fileinfo opcache

# Apache : mod_rewrite + DocumentRoot vers public/ (layout Moodle 5.x)
RUN a2enmod rewrite headers
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}/!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf && \
    printf '<Directory /var/www/html/public>\n    AllowOverride All\n    Require all granted\n</Directory>\n' > /etc/apache2/conf-available/moodle.conf && \
    a2enconf moodle

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Code source IOMAD
COPY . /var/www/html/

# Dépendances PHP (vendor/ régénéré dans l'image) puis on retire composer
RUN cd /var/www/html && composer install --no-dev --classmap-authoritative --no-interaction && \
    rm -f /usr/bin/composer

# Copie "pristine" de public/ HORS du point de montage du volume.
# Sert de source au rsync du boot : permet de mettre à jour le cœur
# tout en préservant les plugins/thèmes uploadés via l'UI (stockés dans le volume).
RUN cp -a /var/www/html/public /opt/iomad-dist-public

# moodledata (hors docroot) + permissions
RUN mkdir -p /var/www/moodledata && \
    chown -R www-data:www-data /var/www && \
    chmod -R 755 /var/www/html

# Cron Moodle (scripts CLI à la RACINE en layout 5.x : admin/cli/, pas public/)
RUN echo "* * * * * www-data /usr/local/bin/php /var/www/html/admin/cli/cron.php > /dev/null 2>&1" > /etc/cron.d/moodle-cron && \
    chmod 0644 /etc/cron.d/moodle-cron

# Entrypoint : config.php depuis ENV + rsync + install/upgrade auto
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD curl -fsS http://localhost/login/index.php > /dev/null || exit 1

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
