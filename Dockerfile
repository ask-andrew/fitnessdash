FROM ghcr.io/linuxserver/baseimage-alpine:3.21

WORKDIR /var/www

RUN apk add --no-cache \
  bash \
  composer \
  curl \
  nginx \
  php83 \
  php83-bcmath \
  php83-ctype \
  php83-curl \
  php83-dom \
  php83-fileinfo \
  php83-fpm \
  php83-gd \
  php83-iconv \
  php83-intl \
  php83-mbstring \
  php83-opcache \
  php83-openssl \
  php83-pdo \
  php83-pdo_sqlite \
  php83-phar \
  php83-session \
  php83-simplexml \
  php83-tokenizer \
  php83-xml \
  php83-xmlreader \
  php83-xmlwriter \
  php83-zip \
  php83-pcntl

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
ENV PHP_INI_DIR="/etc/php83"
RUN ln -s /usr/bin/php83 /usr/bin/php
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
