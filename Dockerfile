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
    icu-libs \
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
    gnu-libiconv \
    $PHPIZE_DEPS

# Set environment variables for iconv
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# Install PHP extensions one by one to isolate issues
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm

# Install extensions in separate RUN commands to isolate any failures
RUN docker-php-ext-install -j$(nproc) bcmath
RUN docker-php-ext-install -j$(nproc) ctype
RUN docker-php-ext-install -j$(nproc) curl
RUN docker-php-ext-install -j$(nproc) dom
RUN docker-php-ext-install -j$(nproc) fileinfo
RUN docker-php-ext-install -j$(nproc) gd
RUN docker-php-ext-install -j$(nproc) intl
RUN docker-php-ext-install -j$(nproc) mbstring
RUN docker-php-ext-install -j$(nproc) opcache
RUN docker-php-ext-install -j$(nproc) pdo
RUN docker-php-ext-install -j$(nproc) pdo_mysql
RUN docker-php-ext-install -j$(nproc) pdo_pgsql
RUN docker-php-ext-install -j$(nproc) pdo_sqlite
RUN docker-php-ext-install -j$(nproc) pcntl
RUN docker-php-ext-install -j$(nproc) session
RUN docker-php-ext-install -j$(nproc) simplexml
RUN docker-php-ext-install -j$(nproc) tokenizer
RUN docker-php-ext-install -j$(nproc) xml
RUN docker-php-ext-install -j$(nproc) xmlreader
RUN docker-php-ext-install -j$(nproc) xmlwriter
RUN docker-php-ext-install -j$(nproc) zip

# Install iconv separately with specific flags
RUN apk add --no-cache gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so
RUN docker-php-ext-install -j$(nproc) iconv

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
