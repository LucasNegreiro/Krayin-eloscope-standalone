#!/bin/bash

# Script de Redeploy Rápido - Krayin CRM
# Para atualizações rápidas sem rebuild completo
# Autor: Redeploy Script
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
    log_error "Arquivo .env não encontrado. Execute primeiro o deploy.sh"
    exit 1
fi

log "🔄 Iniciando redeploy rápido do Krayin CRM..."

# Opções de redeploy
echo "Selecione o tipo de redeploy:"
echo "1) Redeploy simples (restart containers)"
echo "2) Redeploy com pull de imagens"
echo "3) Redeploy com rebuild da aplicação"
echo "4) Redeploy completo (equivalente ao deploy.sh)"
read -p "Escolha uma opção (1-4): " OPTION

case $OPTION in
    1)
        log "🔄 Executando redeploy simples..."
        
        # Restart containers
        log "Reiniciando containers..."
        docker-compose restart
        log_success "Containers reiniciados"
        ;;
        
    2)
        log "📥 Executando redeploy com pull..."
        
        # Pull de imagens
        log "Fazendo pull das imagens..."
        docker-compose pull
        log_success "Pull concluído"
        
        # Restart com novas imagens
        log "Reiniciando com novas imagens..."
        docker-compose up -d
        log_success "Containers atualizados"
        ;;
        
    3)
        log "🔨 Executando redeploy com rebuild..."
        
        # Parar containers
        log "Parando containers..."
        docker-compose down
        log_success "Containers parados"
        
        # Rebuild aplicação
        log "Fazendo rebuild da aplicação..."
        docker-compose build krayin_app
        log_success "Rebuild concluído"
        
        # Subir containers
        log "Subindo containers..."
        docker-compose up -d
        log_success "Containers iniciados"
        
        # Aguardar e executar setup
        log "Aguardando MySQL..."
        sleep 20
        
        log "Executando setup da aplicação..."
        docker-compose exec krayin_app bash /var/www/html/setup.sh
        log_success "Setup concluído"
        ;;
        
    4)
        log "🚀 Executando redeploy completo..."
        
        if [ -f "deploy.sh" ]; then
            log "Executando deploy.sh..."
            bash deploy.sh
        else
            log_error "Arquivo deploy.sh não encontrado"
            exit 1
        fi
        ;;
        
    *)
        log_error "Opção inválida"
        exit 1
        ;;
esac

# Aguardar containers estarem prontos
log "⏳ Aguardando containers estarem prontos..."
sleep 10

# Verificar saúde dos containers
log "🏥 Verificando saúde dos containers..."
if docker-compose ps | grep -q "Up"; then
    log_success "Containers estão rodando"
else
    log_error "Alguns containers não estão rodando"
    docker-compose ps
    exit 1
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
log_success "🎉 Redeploy concluído com sucesso!"
echo
echo "📋 Informações:"
echo "   • URL: https://$DOMAIN"
echo "   • Login: admin@example.com"
echo "   • Senha: admin"
echo "   • Data: $(date)"
echo
echo "📊 Status dos containers:"
docker-compose ps
echo
echo "📝 Comandos úteis:"
echo "   • Ver logs: docker-compose logs -f"
echo "   • Parar: docker-compose down"
echo "   • Reiniciar: docker-compose restart"
echo "   • Status: docker-compose ps"
echo
log "Redeploy finalizado!"