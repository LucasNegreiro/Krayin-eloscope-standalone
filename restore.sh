#!/bin/bash

# Script de Restore - Krayin CRM Database
# Autor: Restore Script
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

# Verificar se foi fornecido um arquivo de backup
if [ $# -eq 0 ]; then
    echo "Uso: $0 <arquivo_backup>"
    echo
    echo "Exemplos:"
    echo "  $0 backups/krayin_backup_20240128_143022.sql.gz"
    echo "  $0 /caminho/para/backup.sql"
    echo
    echo "Backups disponíveis:"
    ls -lah backups/krayin_backup_*.sql.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}' || echo "  Nenhum backup encontrado"
    exit 1
fi

BACKUP_FILE="$1"

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    log_error "Arquivo docker-compose.yml não encontrado. Execute o script no diretório do projeto."
    exit 1
fi

# Verificar se arquivo .env existe
if [ ! -f ".env" ]; then
    log_error "Arquivo .env não encontrado."
    exit 1
fi

# Verificar se o arquivo de backup existe
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Arquivo de backup não encontrado: $BACKUP_FILE"
    exit 1
fi

# Carregar variáveis do .env
source .env

# Verificar se as variáveis necessárias existem
if [ -z "$MYSQL_ROOT_PASSWORD" ] || [ -z "$MYSQL_DATABASE" ]; then
    log_error "Variáveis MYSQL_ROOT_PASSWORD ou MYSQL_DATABASE não encontradas no .env"
    exit 1
fi

log "🔄 Iniciando restore do banco de dados Krayin..."
log "Arquivo de backup: $BACKUP_FILE"

# Confirmação de segurança
echo
log_warning "⚠️  ATENÇÃO: Esta operação irá SUBSTITUIR todos os dados do banco '$MYSQL_DATABASE'!"
echo
read -p "Tem certeza que deseja continuar? Digite 'CONFIRMO' para prosseguir: " CONFIRMATION

if [ "$CONFIRMATION" != "CONFIRMO" ]; then
    log "Operação cancelada pelo usuário."
    exit 0
fi

# Verificar se o container MySQL está rodando
if ! docker-compose ps krayin_mysql | grep -q "Up"; then
    log_warning "Container MySQL não está rodando. Iniciando..."
    docker-compose up -d krayin_mysql
    
    # Aguardar MySQL estar pronto
    log "Aguardando MySQL estar pronto..."
    for i in {1..30}; do
        if docker-compose exec -T krayin_mysql mysqladmin ping -h localhost -u root -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; then
            log_success "MySQL está pronto"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Timeout aguardando MySQL"
            exit 1
        fi
        sleep 2
    done
else
    log_success "Container MySQL está rodando"
fi

# Criar backup de segurança antes do restore
log "💾 Criando backup de segurança antes do restore..."
SAFETY_BACKUP="backups/safety_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
mkdir -p backups

if docker-compose exec -T krayin_mysql mysqldump \
    -u root \
    -p"$MYSQL_ROOT_PASSWORD" \
    --single-transaction \
    "$MYSQL_DATABASE" | gzip > "$SAFETY_BACKUP"; then
    log_success "Backup de segurança criado: $SAFETY_BACKUP"
else
    log_warning "Falha ao criar backup de segurança, continuando..."
fi

# Determinar se o arquivo está comprimido
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log "Arquivo comprimido detectado, descomprimindo..."
    RESTORE_COMMAND="zcat \"$BACKUP_FILE\""
else
    log "Arquivo não comprimido detectado"
    RESTORE_COMMAND="cat \"$BACKUP_FILE\""
fi

# Parar aplicação para evitar conflitos
log "🛑 Parando aplicação temporariamente..."
docker-compose stop krayin_app

# Executar restore
log "🔄 Executando restore do banco '$MYSQL_DATABASE'..."

if eval "$RESTORE_COMMAND" | docker-compose exec -T krayin_mysql mysql \
    -u root \
    -p"$MYSQL_ROOT_PASSWORD" \
    "$MYSQL_DATABASE"; then
    
    log_success "Restore executado com sucesso!"
else
    log_error "Falha no restore"
    
    # Tentar restaurar backup de segurança
    if [ -f "$SAFETY_BACKUP" ]; then
        log_warning "Tentando restaurar backup de segurança..."
        if zcat "$SAFETY_BACKUP" | docker-compose exec -T krayin_mysql mysql \
            -u root \
            -p"$MYSQL_ROOT_PASSWORD" \
            "$MYSQL_DATABASE"; then
            log_success "Backup de segurança restaurado"
        else
            log_error "Falha ao restaurar backup de segurança"
        fi
    fi
    
    exit 1
fi

# Reiniciar aplicação
log "🚀 Reiniciando aplicação..."
docker-compose start krayin_app

# Aguardar aplicação estar pronta
log "⏳ Aguardando aplicação estar pronta..."
sleep 10

# Verificar saúde dos containers
log "🏥 Verificando saúde dos containers..."
if docker-compose ps | grep -q "Up"; then
    log_success "Containers estão rodando"
else
    log_error "Alguns containers não estão rodando"
    docker-compose ps
fi

# Teste de conectividade
log "🌐 Testando conectividade..."
DOMAIN=$(grep KRAYIN_DOMAIN .env | cut -d'=' -f2)
if curl -f -s -o /dev/null "https://$DOMAIN" --max-time 10; then
    log_success "Aplicação está respondendo"
else
    log_warning "Aplicação pode não estar totalmente pronta. Aguarde alguns minutos."
fi

# Mostrar informações finais
echo
log_success "🎉 Restore concluído com sucesso!"
echo
echo "📋 Informações do Restore:"
echo "   • Arquivo restaurado: $BACKUP_FILE"
echo "   • Banco: $MYSQL_DATABASE"
echo "   • Data: $(date)"
echo "   • Backup de segurança: $SAFETY_BACKUP"
echo
echo "📝 Próximos passos:"
echo "   • Verifique se a aplicação está funcionando corretamente"
echo "   • Teste o login e funcionalidades principais"
echo "   • Se houver problemas, use o backup de segurança para reverter"
echo
log "Restore finalizado!"