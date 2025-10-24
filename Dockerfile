FROM ghcr.io/linuxserver/baseimage-alpine:3.21

# Setup document root
WORKDIR /var/www

# Install packages and remove default server definition
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

# Configure nginx - http
COPY nginx.conf /etc/nginx/nginx.conf
# Configure nginx - default server
COPY default.conf /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
ENV PHP_INI_DIR="/etc/php84"
RUN ln -s /usr/bin/php84 /usr/bin/php
COPY fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY php.ini ${PHP_INI_DIR}/conf.d/custom.ini

COPY root /

# Add application
COPY . /var/www/

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction || (echo "Composer install failed" && cat /var/www/composer.json && exit 1)

# Create build directories with proper permissions (after copying app)
RUN mkdir -p /var/www/build/html /var/www/build/cache
RUN mkdir -p /var/www/storage/database /var/www/storage/files
RUN mkdir -p /var/www/var/cache/dev /var/www/var/log
RUN chown -R abc:abc /var/www/build /var/www/storage /var/www/var
RUN chmod -R 755 /var/www/build
RUN chmod -R 755 /var/www/storage
RUN chmod -R 755 /var/www/var
ENV PUID=65534
ENV PGID=100

# Expose the port nginx is reachable on
EXPOSE 8080

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1
