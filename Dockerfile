# Use official PHP 8.3 image with FPM
FROM php:8.3-fpm-alpine

WORKDIR /var/www

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    nginx \
    supervisor \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    icu-dev \
    oniguruma-dev \
    postgresql-dev \
    sqlite-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxpm-dev \
    zlib-dev \
    libzip-dev \
    curl-dev \
    openssl-dev \
    pkgconfig \
    libtool \
    $PHPIZE_DEPS

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm && \
    docker-php-ext-install -j$(nproc) \
        bcmath \
        ctype \
        curl \
        dom \
        fileinfo \
        gd \
        iconv \
        intl \
        mbstring \
        opcache \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        pcntl \
        session \
        simplexml \
        tokenizer \
        xml \
        xmlreader \
        xmlwriter \
        zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
COPY fpm-pool.conf /usr/local/etc/php-fpm.d/zzz-www.conf
COPY php.ini /usr/local/etc/php/conf.d/custom.ini

# Set working directory
WORKDIR /var/www

# Copy root files if they exist
COPY root/ /tmp/root/
RUN if [ -d /tmp/root ]; then cp -r /tmp/root/* /; fi

# Copy composer files first for build caching
COPY composer.json composer.lock /var/www/

# Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction \
    --ignore-platform-req=ext-bcmath \
    --ignore-platform-req=ext-ctype \
    --ignore-platform-req=ext-dom \
    --ignore-platform-req=ext-pcntl \
    --ignore-platform-req=ext-simplexml \
    --ignore-platform-req=ext-fileinfo \
    --ignore-platform-req=ext-xml

# Copy app
COPY . /var/www/

# Set proper permissions
RUN mkdir -p /var/www/var/cache /var/www/var/logs /var/www/var/sessions \
    && chown -R www-data:www-data /var/www/var

# Verify extensions
RUN set -e && \
  required_exts="bcmath ctype fileinfo xml simplexml dom pcntl pdo pdo_sqlite intl mbstring" && \
  for ext in $required_exts; do \
    php -m | grep -q "$ext" || (echo "Missing PHP extension: $ext" && exit 1); \
  done

# Create necessary directories
RUN mkdir -p /var/www/var/cache/prod /var/www/var/logs /var/www/var/sessions \
    && chown -R www-data:www-data /var/www/var

# Expose port 80
EXPOSE 80

# Start Nginx and PHP-FPM
CMD ["nginx", "-g", "daemon off;"]

ENV PUID=65534
ENV PGID=100

USER abc
EXPOSE 8080

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1
