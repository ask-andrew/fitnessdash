FROM ghcr.io/linuxserver/baseimage-alpine:3.21

WORKDIR /var/www

RUN apk add --no-cache \
  bash \
  composer \
  curl \
  nginx \
  php84 \
  php84-bcmath \
  php84-ctype \
  php84-curl \
  php84-dom \
  php84-fileinfo \
  php84-fpm \
  php84-gd \
  php84-iconv \
  php84-intl \
  php84-mbstring \
  php84-opcache \
  php84-openssl \
  php84-pdo \
  php84-pdo_sqlite \
  php84-phar \
  php84-session \
  php84-simplexml \
  php84-tokenizer \
  php84-xml \
  php84-xmlreader \
  php84-xmlwriter \
  php84-zip \
  php84-pcntl

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
ENV PHP_INI_DIR="/etc/php84"
RUN [ -f /usr/bin/php ] || ln -s /usr/bin/php84 /usr/bin/php
COPY fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY php.ini ${PHP_INI_DIR}/conf.d/custom.ini

COPY root /

# Copy composer files first for build caching
COPY composer.json composer.lock /var/www/
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

# Copy app
COPY . /var/www/

# Verify extensions
RUN set -e && \
  required_exts="bcmath ctype fileinfo xml simplexml dom pcntl pdo pdo_sqlite intl mbstring" && \
  for ext in $required_exts; do \
    php -m | grep -q "$ext" || (echo "Missing PHP extension: $ext" && exit 1); \
  done

# Create build directories
RUN mkdir -p /var/www/build/html /var/www/build/cache \
    /var/www/storage/database /var/www/storage/files \
    /var/www/var/cache/dev /var/www/var/log && \
    chown -R abc:abc /var/www/build /var/www/storage /var/www/var && \
    chmod -R 755 /var/www/build /var/www/storage /var/www/var

ENV PUID=65534
ENV PGID=100

USER abc

EXPOSE 8080

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1
