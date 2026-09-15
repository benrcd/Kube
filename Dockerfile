# syntax=docker/dockerfile:1

# =============================================================================
# Stage 1 — Dependencies
#
# Composer runs in its own stage so that the final image never contains
# Composer itself, Git, or the dev dependencies. Dependency installation is
# split from the source copy so that editing application code does not
# invalidate the (slow) dependency layer.
# =============================================================================
FROM composer:2.7 AS vendor

WORKDIR /app

# Only the manifests, so this layer is reused until dependencies actually change.
COPY composer.json composer.lock ./

# --no-scripts    : Laravel's post-install artisan hooks need the full source
#                   tree, which has not been copied yet.
# --no-autoloader : the autoloader is generated after the source arrives.
# --no-dev        : PHPUnit and friends do not belong in a deployed image.
RUN composer install \
        --no-dev \
        --no-scripts \
        --no-autoloader \
        --prefer-dist \
        --no-interaction \
        --no-progress

# Now the application source, then a production-grade autoloader.
COPY . .

# .dockerignore strips the contents of bootstrap/cache (correctly — a
# developer's cached config must never be baked into an image), and Docker
# does not create empty directories, so the directory itself is missing.
# dump-autoload triggers Laravel's post-autoload-dump hook, which runs
# package:discover, which writes its manifest here. Recreate it first.
RUN mkdir -p bootstrap/cache \
 && composer dump-autoload --optimize --no-dev


# =============================================================================
# Stage 2 — Runtime
# =============================================================================
FROM php:8.2-apache AS runtime

# -----------------------------------------------------------------------------
# PHP extensions
#
# mbstring, ctype, tokenizer, xml, fileinfo and openssl are already compiled
# into the official image, so only these three need adding:
#   pdo_mysql : the database driver this app uses
#   bcmath    : required by several common Laravel packages
#   opcache   : NOT enabled by default; without it PHP recompiles every source
#               file on every single request
# -----------------------------------------------------------------------------
RUN docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        bcmath \
        opcache

# Opcache tuning for a container that is rebuilt rather than hot-patched.
# validate_timestamps=0 means PHP never stats files looking for changes, which
# is correct here because the code cannot change within a running container.
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.validate_timestamps=0'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

# Production php.ini (the image ships both a development and a production
# variant and uses neither until you pick one).
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# -----------------------------------------------------------------------------
# Apache: document root must point at public/, not the project root, or the
# whole source tree including .env becomes web-accessible.
# -----------------------------------------------------------------------------
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/sites-available/*.conf \
 && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/apache2.conf \
        /etc/apache2/conf-available/*.conf \
 && a2enmod rewrite

# -----------------------------------------------------------------------------
# Application
# -----------------------------------------------------------------------------
WORKDIR /var/www/html

COPY --from=vendor /app /var/www/html

# Same reason as in the vendor stage: .dockerignore strips the contents of
# the storage subdirectories, so Docker drops the directories themselves.
# Laravel does not recreate them and fails at the first cache write or
# Blade compilation, so rebuild the tree here.
#
# Only storage/ and bootstrap/cache/ are written to at runtime. Everything
# else stays owned by root and read-only to the web server, which is both
# more correct and easier to defend than a blanket recursive chmod.
RUN mkdir -p \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache

# A static health target for Kubernetes readiness and liveness probes.
#
# This deliberately does NOT touch application code or routes: the file is
# created at image build time and lives only inside the image. It also does
# not touch the database, which is what you want for a *readiness* probe on
# the web tier — a probe that hits the DB will mark every replica unready
# during a DB blip and take the whole app offline.
RUN echo 'OK' > /var/www/html/public/healthz.html

EXPOSE 80

# Note for later: to satisfy a runAsNonRoot admission policy you will need to
# switch Apache to port 8080 and set APACHE_RUN_USER/APACHE_RUN_GROUP, since
# only root may bind ports below 1024. Leave that until the cluster exists.