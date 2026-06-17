ARG PHP_VERSION=8.2
ARG XDEBUG_ENABLE=false
FROM wordpress:php${PHP_VERSION}-apache

# Install git and unzip (required by Composer for package operations)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Xdebug (opt-in via XDEBUG_ENABLE=true)
RUN if [ "$XDEBUG_ENABLE" = "true" ]; then \
        pecl install xdebug \
        && docker-php-ext-enable xdebug; \
    fi

COPY xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Install Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install WP-CLI with checksum verification
RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar.sha512 \
       | sha512sum --check \
    && chmod +x /usr/local/bin/wp
