FROM composer:2.7 as composer
FROM node:22.9 as node
FROM php:8.3-apache

ARG container_project_path=/var/www/html/
ARG uid=1000

RUN apt-get update && apt-get install -y \
    git \
    libfreetype6-dev \
    libicu-dev \
    libgmp-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    libonig-dev \
    unzip \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install bcmath gd intl mysqli pdo pdo_mysql zip mbstring xml

RUN a2enmod rewrite
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

RUN useradd -G www-data,root -u $uid -d /home/krayin krayin
RUN mkdir -p /home/krayin/.composer && chown -R krayin:krayin /home/krayin

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

WORKDIR $container_project_path
RUN chown -R krayin:www-data $container_project_path
RUN sed -i 's|/var/www/html|'$container_project_path'/krayin/public|g' /etc/apache2/sites-available/000-default.conf

EXPOSE 80
CMD ["apache2-foreground"]