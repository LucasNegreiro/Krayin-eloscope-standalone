#!/bin/bash

# Script de Backup - Krayin CRM Database
# Autor: Backup Script
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
    log_error "Arquivo .env não encontrado."
    exit 1
fi

# Carregar variáveis do .env
source .env

# Verificar se as variáveis necessárias existem
if [ -z "$MYSQL_ROOT_PASSWORD" ] || [ -z "$MYSQL_DATABASE" ]; then
    log_error "Variáveis MYSQL_ROOT_PASSWORD ou MYSQL_DATABASE não encontradas no .env"
    exit 1
fi

# Criar diretório de backup
BACKUP_DIR="backups"
mkdir -p "$BACKUP_DIR"

# Definir nome do arquivo de backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/krayin_backup_$TIMESTAMP.sql"
BACKUP_COMPRESSED="$BACKUP_DIR/krayin_backup_$TIMESTAMP.sql.gz"

log "💾 Iniciando backup do banco de dados Krayin..."

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

# Fazer backup do banco de dados
log "Criando backup do banco '$MYSQL_DATABASE'..."

if docker-compose exec -T krayin_mysql mysqldump \
    -u root \
    -p"$MYSQL_ROOT_PASSWORD" \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-table \
    --add-locks \
    --create-options \
    --disable-keys \
    --extended-insert \
    --quick \
    "$MYSQL_DATABASE" > "$BACKUP_FILE"; then
    
    log_success "Backup criado: $BACKUP_FILE"
    
    # Comprimir backup
    log "Comprimindo backup..."
    gzip "$BACKUP_FILE"
    log_success "Backup comprimido: $BACKUP_COMPRESSED"
    
    # Mostrar tamanho do arquivo
    BACKUP_SIZE=$(du -h "$BACKUP_COMPRESSED" | cut -f1)
    log "Tamanho do backup: $BACKUP_SIZE"
    
else
    log_error "Falha ao criar backup"
    exit 1
fi

# Limpeza de backups antigos (manter apenas os últimos 7)
log "🧹 Limpando backups antigos..."
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/krayin_backup_*.sql.gz 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt 7 ]; then
    BACKUPS_TO_DELETE=$((BACKUP_COUNT - 7))
    log "Removendo $BACKUPS_TO_DELETE backup(s) antigo(s)..."
    
    ls -1t "$BACKUP_DIR"/krayin_backup_*.sql.gz | tail -n +8 | xargs rm -f
    log_success "Backups antigos removidos"
else
    log "Mantendo todos os $BACKUP_COUNT backup(s) existentes"
fi

# Listar backups disponíveis
echo
log "📋 Backups disponíveis:"
ls -lah "$BACKUP_DIR"/krayin_backup_*.sql.gz 2>/dev/null | awk '{print "   " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}' || log "Nenhum backup encontrado"

echo
log_success "🎉 Backup concluído com sucesso!"
echo
echo "📋 Informações do Backup:"
echo "   • Arquivo: $BACKUP_COMPRESSED"
echo "   • Tamanho: $BACKUP_SIZE"
echo "   • Data: $(date)"
echo "   • Banco: $MYSQL_DATABASE"
echo
echo "🔄 Para restaurar este backup:"
echo "   ./restore.sh $BACKUP_COMPRESSED"
echo
log "Backup finalizado!"