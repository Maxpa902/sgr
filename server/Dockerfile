FROM php:8.4-cli

# Dependencias necesarias para Laravel
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libonig-dev \
    libsqlite3-dev \
    libxml2-dev \
    && docker-php-ext-install \
        mbstring \
        pdo_sqlite \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Composer desde su imagen oficial
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]