#!/bin/bash

# Cores para debug
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para exibir mensagens
log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Função para perguntar ao usuário onde deseja salvar os arquivos
ask_for_output_directory() {
  echo -e "${YELLOW}Deseja salvar os arquivos na pasta atual (${PWD}) ou em outro diretório?${NC}"
  echo "1) Salvar na pasta atual (onde está o script)"
  echo "2) Escolher outro diretório"
  
  read -p "Escolha uma opção (1 ou 2): " choice

  if [ "$choice" -eq 1 ]; then
    OUTPUT_DIR="${PWD}/$(basename "$CHANNEL_URL" | sed 's/[@]//')"  # Diretório no mesmo local do script
    success "Escolhido: Salvar na pasta atual do script."
  elif [ "$choice" -eq 2 ]; then
    read -p "Digite o caminho do diretório de destino: " custom_dir
    if [ ! -d "$custom_dir" ]; then
      error "O diretório '$custom_dir' não existe. Saindo..."
      exit 1
    fi
    OUTPUT_DIR="$custom_dir/$(basename "$CHANNEL_URL" | sed 's/[@]//')"  # Diretório no caminho escolhido
    success "Escolhido: Salvar em '$custom_dir'."
  else
    error "Opção inválida. Saindo..."
    exit 1
  fi
}

# Perguntar o link do canal após a execução do script
ask_for_channel_url() {
  read -p "Digite o link do canal do YouTube que você deseja baixar: " CHANNEL_URL

  if [[ ! "$CHANNEL_URL" =~ ^https://www.youtube.com/.* ]]; then
    error "URL inválida. Por favor, insira um link válido do YouTube."
    exit 1
  fi

  CHANNEL_NAME=$(basename "$CHANNEL_URL" | sed 's/[@]//')  # Extrai o nome do canal a partir da URL
  success "Canal selecionado: $CHANNEL_URL"
}

# Configurações
ask_for_channel_url  # Perguntar pela URL do canal
ask_for_output_directory  # Perguntar onde salvar os arquivos

VIDEOS_DIR="$OUTPUT_DIR/videos"  # Pasta para vídeos
LIVES_DIR="$OUTPUT_DIR/lives"  # Pasta para lives
SHORTS_DIR="$OUTPUT_DIR/shorts"  # Pasta para shorts
THUMBS_VIDEOS_DIR="$VIDEOS_DIR/thumbnails"  # Pasta para thumbnails de vídeos
THUMBS_LIVES_DIR="$LIVES_DIR/thumbnails"  # Pasta para thumbnails de lives
CHROME_DRIVER_PATH="/usr/bin/chromedriver"  # Caminho do ChromeDriver, se necessário

# Função para criar pastas
prepare_directory() {
  if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    success "Diretório principal criado: $OUTPUT_DIR"
  fi

  if [ ! -d "$VIDEOS_DIR" ]; then
    mkdir -p "$VIDEOS_DIR"
    success "Diretório de vídeos criado: $VIDEOS_DIR"
  fi

  if [ ! -d "$LIVES_DIR" ]; then
    mkdir -p "$LIVES_DIR"
    success "Diretório de lives criado: $LIVES_DIR"
  fi

  if [ ! -d "$SHORTS_DIR" ]; then
    mkdir -p "$SHORTS_DIR"
    success "Diretório de shorts criado: $SHORTS_DIR"
  fi

  if [ ! -d "$THUMBS_VIDEOS_DIR" ]; then
    mkdir -p "$THUMBS_VIDEOS_DIR"
    success "Diretório de thumbnails de vídeos criado: $THUMBS_VIDEOS_DIR"
  fi

  if [ ! -d "$THUMBS_LIVES_DIR" ]; then
    mkdir -p "$THUMBS_LIVES_DIR"
    success "Diretório de thumbnails de lives criado: $THUMBS_LIVES_DIR"
  fi
}

# Função para baixar vídeos, lives, shorts e thumbnails com o formato ajustado
download_videos() {
  log "Iniciando download dos vídeos, lives e shorts do canal: $CHANNEL_URL"

  # Construir as URLs para vídeos, lives e shorts usando o nome do canal
  VIDEOS_URL="https://www.youtube.com/@$CHANNEL_NAME/videos"
  LIVES_URL="https://www.youtube.com/@$CHANNEL_NAME/streams"
  SHORTS_URL="https://www.youtube.com/@$CHANNEL_NAME/shorts"
  
  # Baixar vídeos da aba de vídeos e também as thumbnails
  yt-dlp -ciw --write-thumbnail --no-write-info-json -o "$VIDEOS_DIR/A%(upload_date>%Y)s-M%(upload_date>%m)s-D%(upload_date>%d)s_%(timestamp>%H)02dh%(timestamp>%M)02dm%(timestamp>%S)02ds-%(title)s.%(ext)s" \
         --yes-playlist "$VIDEOS_URL" || true  # Continue mesmo que falhe

  # Baixar somente lives da aba de lives e também as thumbnails
  yt-dlp -ciw --write-thumbnail --no-write-info-json -o "$LIVES_DIR/A%(upload_date>%Y)s-M%(upload_date>%m)s-D%(upload_date>%d)s_%(timestamp>%H)02dh%(timestamp>%M)02dm%(timestamp>%S)02ds-%(title)s.%(ext)s" \
         --yes-playlist "$LIVES_URL" || true  # Continue mesmo que falhe

  # Baixar shorts da aba de shorts (sem thumbnails)
  yt-dlp -ciw -o "$SHORTS_DIR/A%(upload_date>%Y)s-M%(upload_date>%m)s-D%(upload_date>%d)s_%(timestamp>%H)02dh%(timestamp>%M)02dm%(timestamp>%S)02ds-%(title)s.%(ext)s" \
         --yes-playlist "$SHORTS_URL" || true  # Continue mesmo que falhe

  success "Downloads concluídos (se houver conteúdo)."
}

# Função para mover as thumbnails para as pastas corretas
move_thumbnails() {
  log "Movendo as thumbnails para as pastas corretas e removendo as inválidas..."

  # Verificar e mover thumbnails de vídeos e lives (remover as inválidas)
  for thumbnail in "$OUTPUT_DIR"/*/*.jpg "$OUTPUT_DIR"/*/*.jpeg "$OUTPUT_DIR"/*/*.png "$OUTPUT_DIR"/*/*.webp; do
    if [ -f "$thumbnail" ]; then
      # Verificar se o nome da thumbnail NÃO corresponde ao padrão de data e hora "AYYYY-MM-DD_HHmmss"
      if [[ ! "$thumbnail" =~ /A[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}h[0-9]{2}m[0-9]{2}s-.* ]] && [[ "$thumbnail" == *"NA"* ]]; then
        # Se o nome NÃO corresponder ao padrão de data e hora, EXCLUIR o arquivo
        rm "$thumbnail"
        log "Thumbnail inválida removida (não corresponde ao padrão de data e hora): $thumbnail"
      else
        # Caso contrário, mover o arquivo para o diretório correto (Vídeos ou Lives)
        if [[ "$thumbnail" == *"live"* ]]; then
          mv "$thumbnail" "$THUMBS_LIVES_DIR/"
          success "Thumbnail de live movida para: $THUMBS_LIVES_DIR/"
        else
          mv "$thumbnail" "$THUMBS_VIDEOS_DIR/"
          success "Thumbnail de vídeo movida para: $THUMBS_VIDEOS_DIR/"
        fi
      fi
    fi
  done
}

# Função para capturar screenshot com a melhor resolução possível
capture_screenshot() {
  log "Capturando screenshot da página inicial do canal..."

  # Usando Python com Selenium para capturar print
  python3 <<EOF
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

# Caminho do seu chromedriver
chromedriver_path = "$CHROME_DRIVER_PATH"  # Caminho do chromedriver

# Configuração do Chrome
options = Options()
options.add_argument("--headless")  # Roda em modo headless (sem interface gráfica)
options.add_argument("--disable-gpu")  # Desabilita GPU (útil para sistemas com recursos limitados)
options.add_argument("--window-size=4000x2160")  # Define uma resolução de 4000x2160 para uma captura de alta qualidade
options.add_argument("--start-maximized")  # Garante que a janela seja maximizada
options.add_argument("--disable-software-rasterizer")  # Desativa o rasterizador de software para melhorar o desempenho gráfico

# Inicia o serviço do ChromeDriver
service = Service(chromedriver_path)

# Inicializa o driver
driver = webdriver.Chrome(service=service, options=options)

# Ajusta a densidade de pixels para melhorar a qualidade da imagem (dobro de pixels)
driver.execute_script("window.devicePixelRatio = 2;")

# Acesse a URL do canal
driver.get("$CHANNEL_URL")

# Espera até que um elemento chave da página esteja visível (ajuste conforme necessário)
try:
    # Espera até que o título da página esteja presente
    WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.TAG_NAME, "h1"))  # Aguarda o título da página
    )

    # Atualiza a página para garantir que o conteúdo está carregado
    driver.refresh()

    # Espera mais um pouco após o reload para garantir o carregamento completo
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.TAG_NAME, "h1"))  # Aguarda o título da página após o reload
    )

    # Rolagem até o final da página para garantir que todas as imagens carreguem
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    time.sleep(2)  # Espera um pouco para garantir que o conteúdo carregue completamente

    # Captura uma screenshot
    driver.save_screenshot("$OUTPUT_DIR/channel_screenshot.png")

    # Fecha o navegador
    driver.quit()
except Exception as e:
    driver.quit()
    print(f"Falha ao capturar o screenshot: {e}")
    exit(1)

EOF

  # Verifica se o screenshot foi salvo corretamente
  if [ -f "$OUTPUT_DIR/channel_screenshot.png" ]; then
    success "Screenshot salvo em: $OUTPUT_DIR/channel_screenshot.png"
  else
    error "Falha ao capturar o screenshot."
    exit 1
  fi
}

# Função para remover pastas vazias
remove_empty_directories() {
  log "Removendo pastas vazias..."

  # Usando find para remover pastas vazias de forma recursiva
  find "$OUTPUT_DIR" -type d -empty -exec rmdir {} \;

  # Remover especificamente as pastas principais (videos e lives) caso estejam vazias
  if [ ! "$(ls -A "$VIDEOS_DIR")" ]; then
    rmdir "$VIDEOS_DIR"
    log "Pasta vazia removida: $VIDEOS_DIR"
  fi

  if [ ! "$(ls -A "$LIVES_DIR")" ]; then
    rmdir "$LIVES_DIR"
    log "Pasta vazia removida: $LIVES_DIR"
  fi

  success "Pastas vazias removidas."
}

# Função principal
main() {
  log "Preparando ambiente..."
  prepare_directory

  log "Iniciando processo de download..."
  download_videos  # Baixar vídeos, lives e shorts, ignorando falhas

  log "Movendo as thumbnails para as pastas corretas..."
  move_thumbnails

  log "Capturando página inicial do canal..."
  capture_screenshot

  log "Removendo pastas vazias..."
  remove_empty_directories

  success "Processo completo. Verifique a pasta: $OUTPUT_DIR"
}

# Executa o script
main
