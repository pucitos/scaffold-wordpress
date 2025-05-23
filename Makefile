# Cerca il file .env e carica le variabili, altrimenti usa .env.example
ENV_FILE := .env
# Ottiene e esporta l'UID e GID dell'utente host corrente
# Questi saranno usati da docker-compose.override.yml per allineare i permessi
HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)
DEV_USER := "devuser"
DEV_GROUP := "devgroup"
export HOST_UID
export HOST_GID
export DEV_USER
export DEV_GROUP

ifneq ($(wildcard $(ENV_FILE)),)
    include $(ENV_FILE)
    export $(shell sed 's/=.*//' $(ENV_FILE) | grep -Ev '^#|^$$')
else ifneq ($(wildcard .env.example),)
    $(warning ".env file not found, using .env.example. Please run 'make setup'")
    include .env.example
    export $(shell sed 's/=.*//' .env.example | grep -Ev '^#|^$$')
endif

# Nome del progetto Docker Compose, default nome cartella corrente
# Usato per i prefissi di container, network, volumi e per i nomi dei progetti dev/prod in Docker Compose
PROJECT_NAME ?= $(shell basename $(CURDIR))

# Nome dell'immagine Docker per produzione (dal .env, con fallback)
PROD_IMAGE_NAME ?= $(DOCKER_IMAGE_NAME)
# Tag per l'immagine (dal .env, con fallback a 'latest' se IMAGE_TAG non è definito)
IMAGE_VERSION ?= $(IMAGE_TAG)
ifeq ($(IMAGE_VERSION),)
    IMAGE_VERSION := latest
endif

# Porta locale per lo sviluppo (dal .env, con fallback)
LOCAL_DEV_PORT ?= $(DEV_WP_PORT)

.PHONY: help setup dev-up dev-up-no-cache dev-down dev-logs dev-shell-wp dev-shell-db build push prod-up prod-down prod-pull prod-logs prod-shell-wp prod-shell-db clean

# Variabile TAG per i comandi build e push.
# Se TAG non è passato come argomento a make (es. make build TAG=v1.0.0),
# userà il valore di IMAGE_VERSION come default.
TAG_TO_USE ?= $(TAG)
ifeq ($(TAG_TO_USE),)
    TAG_TO_USE := $(IMAGE_VERSION)
endif


help:
	@echo "Gestione Progetto WordPress con Docker - scaffold-wordpress"
	@echo ""
	@echo "Uso: make [comando]"
	@echo ""
	@echo "Comandi Generali:"
	@echo "  setup             - Copia .env.example in .env (se non esiste)."
	@echo ""
	@echo "Sviluppo Locale:"
	@echo "  dev-up            - Avvia i container di sviluppo (WordPress + DB) su http://localhost:$(LOCAL_DEV_PORT)."
	@echo "  dev-up-no-cache   - Avvia i container di sviluppo, forzando la ricostruzione delle immagini senza cache."
	@echo "  dev-down          - Ferma e rimuove i container e i volumi di sviluppo."
	@echo "  dev-logs          - Mostra i log dei container di sviluppo."
	@echo "  dev-shell-wp      - Apre una shell nel container WordPress di sviluppo."
	@echo "  dev-shell-db      - Apre una shell mysql nel container DB di sviluppo."
	@echo ""
	@echo "Build & Deploy Immagine (per Produzione):"
	@echo "  build [TAG=<tag>] - Costruisce l'immagine Docker di produzione (default TAG: $(IMAGE_VERSION))."
	@echo "                      Esempio: make build TAG=1.0.0"
	@echo "  push [TAG=<tag>]  - Carica l'immagine Docker di produzione su un registry (default TAG: $(IMAGE_VERSION))."
	@echo "                      Esempio: make push TAG=1.0.0"
	@echo ""
	@echo "Comandi da ESEGUIRE SUL SERVER DI PRODUZIONE:"
	@echo "  prod-up           - Avvia i container di produzione (usa immagine pre-costruita da .env)."
	@echo "  prod-down         - Ferma e rimuove i container e i volumi di produzione."
	@echo "  prod-pull         - Scarica l'immagine specificata in .env per il servizio 'wordpress'."
	@echo "  prod-logs         - Mostra i log dei container di produzione."
	@echo "  prod-shell-wp     - Apre una shell nel container WordPress di produzione."
	@echo "  prod-shell-db     - Apre una shell mysql nel container DB di produzione."
	@echo ""
	@echo "Pulizia:"
	@echo "  clean             - Rimuove la cache di build di Docker."

setup:
ifeq ($(wildcard .env),)
	@echo "Creazione del file .env da .env.example..."
	@cp .env.example .env
	@echo "File .env creato. Modificalo con le tue configurazioni specifiche del progetto!"
else
	@echo "Il file .env esiste già. Nessuna azione eseguita."
endif

# Comandi di Sviluppo Locale
# Usano docker-compose.yml e docker-compose.override.yml
# Il flag -p assicura che i nomi dei progetti siano distinti se si usa questo scaffold più volte
dev-up: setup
	@echo "Assicurazione esistenza directory uploads di sviluppo: ./data/dev-uploads ..."
	@mkdir -p ./data/dev-uploads
	@echo "Avvio ambiente di sviluppo del progetto '$(PROJECT_NAME)' su http://localhost:$(LOCAL_DEV_PORT)..."
	@echo "Usando UID=$(HOST_UID) e GID=$(HOST_GID) per il container WordPress."
	# Passa esplicitamente HOST_UID e HOST_GID all'ambiente del comando docker compose
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) DEV_GROUP=$(DEV_GROUP) DEV_USER=$(DEV_USER) docker compose -p $(PROJECT_NAME) up -d --build --remove-orphans

dev-up-no-cache: setup
	@echo "Assicurazione esistenza directory uploads di sviluppo: ./data/dev-uploads ..."
	@mkdir -p ./data/dev-uploads
	@echo "Avvio ambiente di sviluppo del progetto '$(PROJECT_NAME)' su http://localhost:$(LOCAL_DEV_PORT) (FORZANDO REBUILD SENZA CACHE)..."
	@echo "Usando UID=$(HOST_UID) e GID=$(HOST_GID) per il container WordPress (se APP_ENV=development)."
	@echo "Forzando la ricostruzione dell'immagine WordPress senza cache..."
	HOST_UID=$(HOST_UID) DEV_USER=$(DEV_USER) DEV_GROUP=$(DEV_GROUP) docker compose -p $(PROJECT_NAME) build --no-cache wordpress
	@echo "Avvio dei container..."
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) HOST_GID=$(HOST_GID) DEV_USER=$(DEV_USER) DEV_GROUP=$(DEV_GROUP) docker compose -p $(PROJECT_NAME) up -d --remove-orphans


dev-down:
	@echo "Fermo ambiente di sviluppo del progetto '$(PROJECT_NAME)'..."
	@docker compose -p $(PROJECT_NAME) down 

dev-logs:
	@docker compose -p $(PROJECT_NAME) logs -f

dev-shell-wp:
	@docker compose -p $(PROJECT_NAME) exec wordpress bash

dev-shell-db:
	@docker compose -p $(PROJECT_NAME) exec db mysql -u$(DB_USER) -p$(DB_PASSWORD) $(DB_NAME)_dev


# Build e Push Immagine di Produzione
# Assicurati che DOCKER_IMAGE_NAME sia impostato nel tuo .env
build:
	@echo "Costruzione immagine di produzione $(PROD_IMAGE_NAME):$(TAG_TO_USE)..."
	@docker build -t $(PROD_IMAGE_NAME):$(TAG_TO_USE) -f Dockerfile .
push:
	@echo "Push immagine di produzione $(PROD_IMAGE_NAME):$(TAG_TO_USE) al registry..."
	@docker push $(PROD_IMAGE_NAME):$(TAG_TO_USE)

# Comandi per la Produzione (da eseguire sul server di produzione)
# Questi comandi usano solo docker-compose.yml (e il .env del server)
# Il flag -p qui dovrebbe corrispondere al nome del progetto sul server
prod-up:
	@echo "Avvio ambiente di produzione del progetto '$(PROJECT_NAME)'..."
	@docker compose -p $(PROJECT_NAME) -f docker-compose.yml up -d

prod-down:
	@echo "Fermo ambiente di produzione del progetto '$(PROJECT_NAME)'..."
	@docker compose -p $(PROJECT_NAME) -f docker-compose.yml down

prod-pull:
	@echo "Pull dell'immagine $(PROD_IMAGE_NAME):$(IMAGE_VERSION) (servizio 'wordpress') per il progetto '$(PROJECT_NAME)'..."
	@docker compose -p $(PROJECT_NAME) -f docker-compose.yml pull wordpress

prod-logs:
	@docker compose -p $(PROJECT_NAME) -f docker-compose.yml logs -f

prod-shell-wp:
	@docker compose -p $(PROJECT_NAME) -f docker-compose.yml exec wordpress bash

prod-shell-db:
	@docker compose -p $(PROJECT_NAME) -f docker-compose.yml exec db mysql -u$(DB_USER) -p$(DB_PASSWORD) $(DB_NAME)

clean:
	@echo "Rimozione cache di Docker build..."
	@docker builder prune -af