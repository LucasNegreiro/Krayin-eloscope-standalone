#!/bin/bash

# Script de Deploy Automatizado - Krayin CRM
# Autor: Deploy Script
# Data: $(date +"%Y-%m-%d")

set -e  # Parar execução em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    log_error "Arquivo docker-compose.yml não encontrado. Execute o script no diretório do projeto."
    exit 1
fi

# Verificar se arquivo .env existe
if [ ! -f ".env" ]; then
    log_error "Arquivo .env não encontrado. Copie .env.example para .env e configure as variáveis."
    exit 1
fi

log "🚀 Iniciando deploy do Krayin CRM..."

# 1. Verificar redes Docker
log "📡 Verificando redes Docker..."
if ! docker network ls | grep -q "krayin_net"; then
    log "Criando rede krayin_net..."
    docker network create krayin_net
    log_success "Rede krayin_net criada"
else
    log_success "Rede krayin_net já existe"
fi

if ! docker network ls | grep -q "n8n"; then
    log_warning "Rede n8n não encontrada. Criando..."
    docker network create n8n
    log_success "Rede n8n criada"
else
    log_success "Rede n8n já existe"
fi

# 2. Parar containers existentes
log "🛑 Parando containers existentes..."
docker-compose down --remove-orphans
log_success "Containers parados"

# 3. Fazer backup do banco (se existir)
log "💾 Verificando necessidade de backup..."
if docker volume ls | grep -q "krayin_mysql_data"; then
    log "Criando backup do banco de dados..."
    mkdir -p backups
    BACKUP_FILE="backups/krayin_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    # Iniciar apenas o MySQL para backup
    docker-compose up -d krayin_mysql
    sleep 10
    
    # Fazer backup
    docker-compose exec -T krayin_mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" krayin > "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        log_success "Backup criado: $BACKUP_FILE"
    else
        log_warning "Falha no backup, continuando deploy..."
    fi
    
    # Parar MySQL
    docker-compose down
else
    log "Primeira instalação detectada, pulando backup"
fi

# 4. Limpar imagens antigas (opcional)
read -p "Deseja limpar imagens Docker antigas? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "🧹 Limpando imagens antigas..."
    docker system prune -f
    docker image prune -f
    log_success "Limpeza concluída"
fi

# 5. Pull das imagens mais recentes
log "📥 Fazendo pull das imagens..."
docker-compose pull
log_success "Pull das imagens concluído"

# 6. Build da aplicação
log "🔨 Fazendo build da aplicação..."
docker-compose build --no-cache
log_success "Build concluído"

# 7. Subir a stack
log "🚀 Subindo a stack..."
docker-compose up -d
log_success "Stack iniciada"

# 8. Aguardar MySQL estar pronto
log "⏳ Aguardando MySQL estar pronto..."
sleep 30

# Verificar se MySQL está respondendo
for i in {1..30}; do
    if docker-compose exec -T krayin_mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent; then
        log_success "MySQL está pronto"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "Timeout aguardando MySQL"
        exit 1
    fi
    sleep 2
done

# 9. Executar setup da aplicação
log "⚙️ Executando setup da aplicação..."
docker-compose exec krayin_app bash /var/www/html/setup.sh

if [ $? -eq 0 ]; then
    log_success "Setup da aplicação concluído"
else
    log_error "Falha no setup da aplicação"
    exit 1
fi

# 10. Verificar saúde dos containers
log "🏥 Verificando saúde dos containers..."
sleep 10

if docker-compose ps | grep -q "Up"; then
    log_success "Containers estão rodando"
else
    log_error "Alguns containers não estão rodando"
    docker-compose ps
    exit 1
fi

# 11. Teste de conectividade
log "🌐 Testando conectividade..."
if curl -f -s -o /dev/null "https://$(grep KRAYIN_DOMAIN .env | cut -d'=' -f2)"; then
    log_success "Aplicação está respondendo"
else
    log_warning "Aplicação pode não estar totalmente pronta. Verifique manualmente."
fi

# 12. Mostrar informações finais
echo
log_success "🎉 Deploy concluído com sucesso!"
echo
echo "📋 Informações do Deploy:"
echo "   • URL: https://$(grep KRAYIN_DOMAIN .env | cut -d'=' -f2)"
echo "   • Login: admin@example.com"
echo "   • Senha: admin"
echo "   • Data: $(date)"
echo
echo "📊 Status dos containers:"
docker-compose ps
echo
echo "📝 Para verificar logs:"
echo "   docker-compose logs -f"
echo
echo "🔄 Para redeploy rápido:"
echo "   ./redeploy.sh"
echo
log "Deploy finalizado!"