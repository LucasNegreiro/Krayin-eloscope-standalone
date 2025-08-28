# 🚀 Krayin CRM - Deploy via Docker

Este repositório contém todos os arquivos necessários para fazer o deploy do Krayin CRM usando Docker e Portainer.

## 📋 Pré-requisitos

- Docker e Docker Compose instalados
- Portainer configurado (opcional, mas recomendado)
- Acesso SSH ao GitHub configurado
- Redes Docker: `krayin_net` e `n8n`

## 🏗️ Arquitetura

```
┌─────────────────┐    ┌─────────────────┐
│   Traefik       │    │   Krayin App    │
│   (Proxy)       │◄──►│   (PHP/Apache)  │
└─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   MySQL 8.0     │
                       │   (Database)    │
                       └─────────────────┘
```

## 📁 Estrutura do Projeto

```
krayin/
├── docker-compose.yml    # Orquestração dos containers
├── Dockerfile           # Imagem customizada PHP/Apache
├── setup.sh            # Script de instalação automática
├── .env.example        # Template das variáveis de ambiente
├── .env.yml           # Configurações específicas (não commitado)
├── .dockerignore      # Otimização do build context
└── README.md          # Este arquivo
```

## 🚀 Deploy via Portainer (Recomendado)

### Método 1: Git Repository

1. **Acesse o Portainer**: `https://portainer.enovas.com.br`
2. **Vá em Stacks → Add Stack**
3. **Configure:**
   - **Nome**: `krayin-crm`
   - **Build Method**: `Repository`
   - **Repository URL**: `git@github.com:LucasNegreiro/Krayin-eloscope-standalone.git`
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: `docker-compose.yml`

4. **Environment Variables:**
```env
APP_URL=https://crm.enovas.com.br
KRAYIN_DOMAIN=crm.enovas.com.br
MYSQL_ROOT_PASSWORD=SuaSenhaSegura123
MYSQL_DATABASE=krayin_crm
MYSQL_USER=krayin_user
MYSQL_PASSWORD=SuaSenhaSegura123
```

5. **Deploy the stack**

## 🐳 Deploy via Docker Compose

### 1. Clone o Repositório
```bash
git clone git@github.com:LucasNegreiro/Krayin-eloscope-standalone.git
cd Krayin-eloscope-standalone
```

### 2. Configure as Variáveis de Ambiente
```bash
# Copie o template
cp .env.example .env

# Edite as configurações
nano .env
```

### 3. Crie as Redes Docker
```bash
docker network create krayin_net
# A rede 'n8n' deve já existir
```

### 4. Execute o Deploy
```bash
docker-compose up -d
```

### 5. Execute o Setup (Primeira vez)
```bash
# Aguarde os containers iniciarem
sleep 30

# Execute o script de instalação
./setup.sh
```

## ⚙️ Configurações

### Variáveis de Ambiente Obrigatórias

| Variável | Descrição | Exemplo |
|----------|-----------|----------|
| `APP_URL` | URL da aplicação | `https://crm.enovas.com.br` |
| `KRAYIN_DOMAIN` | Domínio para Traefik | `crm.enovas.com.br` |
| `MYSQL_ROOT_PASSWORD` | Senha root do MySQL | `SuaSenhaSegura123` |
| `MYSQL_DATABASE` | Nome do banco de dados | `krayin_crm` |
| `MYSQL_USER` | Usuário do banco | `krayin_user` |
| `MYSQL_PASSWORD` | Senha do usuário | `SuaSenhaSegura123` |

### Configurações Opcionais

```env
# SMTP (Email)
MAIL_MAILER=smtp
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=seu_email@example.com
MAIL_PASSWORD=sua_senha_email
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=seu_email@example.com
MAIL_FROM_NAME="Krayin CRM"

# Timezone
APP_TIMEZONE=America/Sao_Paulo
```

## 🔧 Comandos Úteis

### Verificar Status
```bash
# Ver containers rodando
docker ps | grep krayin

# Ver logs
docker logs krayin_app
docker logs krayin_mysql
```

### Acessar Container
```bash
# Acessar container da aplicação
docker exec -it krayin_app bash

# Acessar MySQL
docker exec -it krayin_mysql mysql -u root -p
```

### Comandos Laravel
```bash
# Dentro do container krayin_app
cd krayin

# Limpar cache
php artisan cache:clear
php artisan config:clear
php artisan view:clear

# Executar migrações
php artisan migrate

# Gerar chave da aplicação
php artisan key:generate
```

### Backup do Banco
```bash
# Fazer backup
docker exec krayin_mysql mysqldump -u root -p krayin_crm > backup.sql

# Restaurar backup
docker exec -i krayin_mysql mysql -u root -p krayin_crm < backup.sql
```

## 🌐 Acesso

- **URL**: `https://crm.enovas.com.br`
- **Login padrão**: `admin@example.com`
- **Senha padrão**: `admin123`

> ⚠️ **Importante**: Altere as credenciais padrão após o primeiro login!

## 🔍 Troubleshooting

### Problema: Container não inicia
```bash
# Verificar logs
docker logs krayin_app
docker logs krayin_mysql

# Verificar redes
docker network ls | grep krayin
```

### Problema: Erro de permissão
```bash
# Corrigir permissões
docker exec krayin_app chown -R www-data:www-data /var/www/html/krayin/storage
docker exec krayin_app chmod -R 775 /var/www/html/krayin/storage
```

### Problema: Banco não conecta
```bash
# Verificar se MySQL está rodando
docker exec krayin_mysql mysql -u root -p -e "SELECT 1;"

# Verificar variáveis de ambiente
docker exec krayin_app env | grep DB_
```

### Problema: Build muito lento
- Verifique se o `.dockerignore` está presente
- Remova arquivos desnecessários do diretório

## 📊 Monitoramento

### Verificar Saúde dos Containers
```bash
# Status geral
docker-compose ps

# Uso de recursos
docker stats krayin_app krayin_mysql

# Logs em tempo real
docker-compose logs -f
```

### Métricas Importantes
- **CPU**: < 80%
- **Memória**: < 2GB por container
- **Disco**: Monitorar volume `krayin_mysql_data`

## 🔄 Atualizações

### Atualizar Krayin
```bash
# Fazer backup primeiro!
./backup.sh

# Atualizar código
docker exec krayin_app bash -c "cd krayin && git pull"

# Executar migrações
docker exec krayin_app bash -c "cd krayin && php artisan migrate"

# Limpar cache
docker exec krayin_app bash -c "cd krayin && php artisan optimize:clear"
```

### Atualizar Containers
```bash
# Rebuild da imagem
docker-compose build --no-cache

# Restart dos serviços
docker-compose down
docker-compose up -d
```

## 🛡️ Segurança

### Recomendações
- ✅ Use senhas fortes para MySQL
- ✅ Configure HTTPS via Traefik
- ✅ Mantenha containers atualizados
- ✅ Faça backups regulares
- ✅ Monitore logs de acesso
- ✅ Use redes Docker isoladas

### Hardening
```bash
# Remover usuário padrão após setup
docker exec krayin_app bash -c "cd krayin && php artisan user:delete admin@example.com"

# Configurar rate limiting
# (configurar no Traefik ou nginx)
```

## 📞 Suporte

### Links Úteis
- [Documentação Krayin](https://krayin.com/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Portainer Documentation](https://docs.portainer.io/)

### Logs para Suporte
```bash
# Coletar logs para análise
docker logs krayin_app > krayin_app.log 2>&1
docker logs krayin_mysql > krayin_mysql.log 2>&1
docker-compose config > docker-compose-parsed.yml
```

---

## 📝 Changelog

### v1.0.0 (2024-01-XX)
- ✅ Setup inicial do projeto
- ✅ Docker Compose configurado
- ✅ Dockerfile otimizado
- ✅ Script de instalação automática
- ✅ Integração com Traefik
- ✅ Documentação completa

---

**Desenvolvido para Enovas** 🚀