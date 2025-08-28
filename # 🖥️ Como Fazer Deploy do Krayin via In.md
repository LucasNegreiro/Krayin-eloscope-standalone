# 🖥️ Como Fazer Deploy do Krayin via Interface Web do Portainer

## 🎯 3 Métodos Disponíveis na Interface Web

### ✅ MÉTODO 1: Git Repository (RECOMENDADO)

Este é o método mais seguro e profissional para deployar o Krayin com build context.

#### Passo 1: Criar Repositório Git
1. **Crie um repositório no GitHub/GitLab** (pode ser privado)
2. **Adicione os seguintes arquivos**:

**docker-compose.yml**
```yaml
version: "3.8"

services:
  krayin_mysql:
    image: mysql:8.0
    container_name: krayin_mysql
    command: --default-authentication-plugin=mysql_native_password
    restart: unless-stopped
    environment:
      MYSQL_ROOT_HOST: '%'
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - krayin_mysql_data:/var/lib/mysql
    networks:
      - krayin_net
    labels:
      - traefik.enable=false

  krayin_app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: krayin_app
    restart: unless-stopped
    depends_on:
      - krayin_mysql
    environment:
      APP_ENV: production
      APP_DEBUG: false
      APP_URL: ${APP_URL}
      DB_CONNECTION: mysql
      DB_HOST: krayin_mysql
      DB_PORT: 3306
      DB_DATABASE: ${MYSQL_DATABASE}
      DB_USERNAME: ${MYSQL_USER}
      DB_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - krayin_workspace:/var/www/html
    networks:
      - krayin_net
      - n8n
    labels:
      - traefik.enable=true
      - traefik.http.routers.krayin.rule=Host(`${KRAYIN_DOMAIN}`)
      - traefik.http.routers.krayin.entrypoints=web,websecure
      - traefik.http.routers.krayin.tls.certresolver=leresolver

volumes:
  krayin_mysql_data:
  krayin_workspace:

networks:
  krayin_net:
    external: true
  n8n:
    external: true
```

**Dockerfile**
```dockerfile
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
```

**setup.sh**
```bash
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
```

#### Passo 2: Deploy via Portainer
1. **Acesse Portainer**: `https://portainer.enovas.com.br`
2. **Vá em Stacks → Add Stack**
3. **Nome da Stack**: `krayin-crm`
4. **Build Method**: Selecione **"Repository"**
5. **Configure Repository**:
   - **Repository URL**: `https://github.com/seuusuario/krayin-stack`
   - **Repository reference**: `refs/heads/main` (ou sua branch)
   - **Compose path**: `docker-compose.yml`
6. **Environment variables**:
   ```
   APP_URL=https://crm.enovas.com.br
KRAYIN_DOMAIN=crm.enovas.com.br
   MYSQL_ROOT_PASSWORD=R0Zur842QXc8KrayinRoot
   MYSQL_DATABASE=krayin_crm
   MYSQL_USER=krayin_user
   MYSQL_PASSWORD=R0Zur842QXc8Krayin
   ```
7. **Deploy the stack**

---

### ✅ MÉTODO 2: Upload de Arquivos ZIP

#### Passo 1: Criar Arquivo ZIP
1. **Crie uma pasta** com os 3 arquivos:
   - `docker-compose.yml`
   - `Dockerfile`  
   - `setup.sh`
2. **Compacte em ZIP**

#### Passo 2: Upload no Portainer
1. **Stacks → Add Stack**
2. **Nome**: `krayin-crm`
3. **Build Method**: Selecione **"Upload"**
4. **Upload** o arquivo ZIP
5. **Environment variables**: Adicione as mesmas variáveis do método 1
6. **Deploy the stack**

---

### ⚠️ MÉTODO 3: Web Editor (LIMITADO)

Este método tem limitações porque o Dockerfile precisa estar no build context.

#### Alternativa A: Usar Imagem Pre-construída

**docker-compose.yml modificado**:
```yaml
version: "3.8"

services:
  krayin_mysql:
    image: mysql:8.0
    # ... mesmo config anterior

  krayin_app:
    image: webkul/krayin:latest  # Imagem pré-construída (se existir)
    # ... resto da config
```

#### Alternativa B: Build em 2 Etapas

**Etapa 1**: Criar a imagem via Images → Build:
1. **Images → Build a new image**
2. **Nome**: `krayin-custom:latest`
3. **Web Editor**: Cole o conteúdo do Dockerfile
4. **Build the image**

**Etapa 2**: Usar a imagem na Stack:
```yaml
krayin_app:
  image: krayin-custom:latest
  # ... resto da config
```

---

## 🚀 Execução Pós-Deploy

Independente do método escolhido, após o deploy:

### 1. Verificar Status
```bash
# Via Portainer Console ou SSH
docker ps | grep krayin
docker logs krayin_app
docker logs krayin_mysql
```

### 2. Executar Setup
```bash
# Acessar container
docker exec -it krayin_app bash

# Executar setup (se não automatizado)
chmod +x setup.sh
./setup.sh
```

### 3. Testar Acesso
- **URL**: `https://crm.enovas.com.br`
- **Login**: `admin@example.com`
- **Senha**: `admin123`

---

## 🔧 Troubleshooting Interface Web

### Erro "No such file or directory"
**Causa**: Dockerfile não encontrado no build context
**Solução**: Use Método 1 (Git Repository) ou Método 2 (Upload ZIP)

### Erro "Permission denied"
```bash
# Corrigir permissões
docker exec -it krayin_app chown -R www-data:www-data /var/www/html/krayin
```

### Build muito lento
**Causa**: Build context muito grande
**Solução**: Adicione `.dockerignore`:
```
node_modules/
.git/
*.log
```

### Erro de rede
**Causa**: Redes não existem
**Solução**:
```bash
# Criar redes necessárias
docker network create krayin_net
# rede n8n já existe
```

---

## 📊 Comparação dos Métodos

| Método | Facilidade | Segurança | Manutenção | Recomendado |
|--------|------------|-----------|------------|-------------|
| Git Repository | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ SIM |
| Upload ZIP | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ✅ SIM |
| Web Editor | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ❌ NÃO |

---

## 🎯 Recomendação Final

**Use o MÉTODO 1 (Git Repository)** porque:
- ✅ **Versionamento**: Controle total das mudanças
- ✅ **Backup**: Código sempre salvo no Git
- ✅ **Colaboração**: Equipe pode contribuir
- ✅ **CI/CD**: Pode integrar automação futura
- ✅ **Segurança**: Não precisa fazer upload manual

O **MÉTODO 2 (Upload ZIP)** é boa alternativa se você não quiser usar Git.

**EVITE o MÉTODO 3 (Web Editor)** para este caso específico do Krayin que requer build context.