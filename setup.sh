#!/bin/bash

echo "🚀 Iniciando instalação do Krayin CRM"

apache_container_id=$(docker ps -aqf "name=krayin_app")
db_container_id=$(docker ps -aqf "name=krayin_mysql")

while ! docker exec ${db_container_id} mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "SELECT 1" >/dev/null 2>&1; do
    echo "Aguardando MySQL..."
    sleep 3
done

docker exec ${db_container_id} mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

docker exec ${apache_container_id} git clone https://github.com/krayin/laravel-crm krayin
docker exec -i ${apache_container_id} bash -c "cd krayin && git reset --hard v2.1.2"
docker exec -i ${apache_container_id} bash -c "cd krayin && composer install --no-dev --optimize-autoloader"
docker exec -i ${apache_container_id} bash -c "cd krayin && cp .env.example .env"

# Configurar .env
docker exec -i ${apache_container_id} bash -c "cd krayin && sed -i 's|APP_URL=.*|APP_URL=${APP_URL}|g' .env"
docker exec -i ${apache_container_id} bash -c "cd krayin && sed -i 's|DB_HOST=.*|DB_HOST=krayin_mysql|g' .env"
docker exec -i ${apache_container_id} bash -c "cd krayin && sed -i 's|DB_DATABASE=.*|DB_DATABASE=${MYSQL_DATABASE}|g' .env"
docker exec -i ${apache_container_id} bash -c "cd krayin && sed -i 's|DB_USERNAME=.*|DB_USERNAME=${MYSQL_USER}|g' .env"
docker exec -i ${apache_container_id} bash -c "cd krayin && sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=${MYSQL_PASSWORD}|g' .env"

docker exec -i ${apache_container_id} sh -c "cd krayin && php artisan key:generate && php artisan optimize:clear && php artisan migrate:fresh --seed && php artisan storage:link"

docker exec -i ${apache_container_id} bash -c "chown -R www-data:www-data /var/www/html/krayin/storage /var/www/html/krayin/bootstrap/cache"
docker exec -i ${apache_container_id} bash -c "chmod -R 775 /var/www/html/krayin/storage /var/www/html/krayin/bootstrap/cache"

echo "✅ Instalação concluída!"