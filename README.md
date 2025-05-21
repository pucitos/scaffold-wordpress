# Scaffold WordPress con Docker

Scaffold per avviare rapidamente un nuovo sito WordPress utilizzando Docker e Docker Compose.
È pensato per facilitare lo sviluppo locale e il deploy in produzione basato su immagini Docker personalizzate.
In produzione è previsto l'utilizzo di Traefik.

## Prerequisiti

- Docker (https://www.docker.com/get-started)
- Docker Compose (solitamente incluso con Docker Desktop)
- Un account su un Docker Registry (es. Docker Hub, GitLab Container Registry) per le immagini di produzione.
- `make` (opzionale, ma il Makefile semplifica i comandi)

## Struttura del Progetto

- `.dockerignore`: Specifica quali file ignorare durante la build dell'immagine Docker.
- `.env.example`: File di esempio per le variabili d'ambiente. **Copialo in `.env` e personalizzalo.**
- `Dockerfile`: Definisce come costruire l'immagine Docker personalizzata per WordPress.
- `docker-compose.yml`: Configurazione base di Docker Compose per l'ambiente di produzione.
- `docker-compose.override.yml`: Sovrascrive e aggiunge configurazioni a `docker-compose.yml` per lo sviluppo locale.
- `Makefile`: Contiene comandi utili per build, sviluppo, deploy, ecc.
- `README.md`: Questo file.
- `src/wp-content/`: Qui andranno inseriti temi, plugin e mu-plugin.
  - `themes/`
  - `plugins/`
  - `mu-plugins/`

## Come Iniziare un Nuovo Progetto

1.  **Clona o Copia questo Scaffold:**

    ```bash
    git clone https://tuo-repository/scaffold-wordpress.git nome-del-tuo-nuovo-progetto
    cd nome-del-tuo-nuovo-progetto
    ```

2.  **Configurazione Iniziale (Makefile):**
    Esegui `make setup`. Questo copierà `.env.example` in `.env` se non esiste.

    ```bash
    make setup
    ```

3.  **Personalizza `.env`:**
    Apri il file `.env` e **modifica tutte le variabili** secondo le necessità del tuo nuovo progetto:

    - `DB_*`: Credenziali del database.
    - `SITE_DOMAIN`, `SITE_SCHEME`: Dominio e schema del tuo sito di produzione.
    - `AUTH_KEY`...`NONCE_SALT`: **Genera nuove chiavi di sicurezza WordPress!** Puoi trovarle su [https://api.wordpress.org/secret-key/1.1/salt/](https://api.wordpress.org/secret-key/1.1/salt/).
    - `DOCKER_IMAGE_NAME`: Il nome completo della tua immagine Docker sul registry (es. `tuoutente/nome-del-tuo-nuovo-progetto`).
    - `IMAGE_TAG`: Il tag di default per le tue immagini (es. `latest` o `1.0.0`).
    - `DEV_WP_PORT`: Porta locale per l'ambiente di sviluppo (default `8000`).

4.  **Aggiungi i tuoi Temi/Plugin:**
    Posiziona i tuoi temi custom in `src/wp-content/themes/` e i plugin in `src/wp-content/plugins/` (o `mu-plugins`).

## Sviluppo Locale

Per avviare l'ambiente di sviluppo locale (WordPress accessibile su `http://localhost:PORTA_DEV`):

```bash
make dev-up
```

Questo comando:

- Costruisce l'immagine Docker (se non già buildata o se il Dockerfile è cambiato).
- Avvia i container WordPress e MariaDB.
- Mappa la tua cartella locale src/wp-content all'interno del container WordPress, permettendo modifiche live al codice.
- Usa volumi Docker separati per i dati del database di sviluppo (db_data_dev) e gli uploads (wp_uploads_dev).

Altri comandi utili per lo sviluppo:

- `make dev-down`: Ferma e rimuove i container e i volumi di sviluppo.
- `make dev-logs`: Mostra i log dei container.
- `make dev-shell-wp`: Apre una shell bash nel container WordPress.
- `make dev-shell-db`: Apre una console MySQL nel container del database.

## Build e Deploy in Produzione

Il deploy in produzione si basa sulla creazione di un'immagine Docker che include il tuo codice (`wp-content`).

1. **Build dell'immagine**: quando sei pronto per rilasciare una nuova versione, builda l'immagine Docker. Assicurati che DOCKER_IMAGE_NAME nel tuo .env sia corretto.

```bash
make build TAG=1.0.0 # Sostituisci 1.0.0 con il tuo tag di versione
```

2. **Push dell'immagine nel repository**:
   carica l'immagine buildata sul tuo Docker Registry.

```bash
make push TAG=1.0.0
# Potrebbe essere necessario eseguire docker login tuo-registry.com prima.
```

3. **Deploy del server di produzione**
   Sul server di produzione:

- Assicurati di avere Docker e Docker Compose installati.
- Copia i file docker-compose.yml e .env (configurato per la produzione!) sul server.
- Se è il primo deploy, crea i volumi Docker necessari (Docker li creerà al primo up se non esistono).
- Esegui i comandi (o usa il Makefile se presente anche sul server):

```bash
# Scarica l'ultima versione dell'immagine specificata in .env
make prod-pull # Oppure: docker compose -p nomeprogettoprod -f docker-compose.yml pull wordpress

# Avvia/Aggiorna i container
make prod-up   # Oppure: docker compose -p nomeprogettoprod -f docker-compose.yml up -d
```

- Reverse Proxy: In un ambiente di produzione reale, dovresti avere un reverse proxy (es. Nginx, Traefik) configurato per gestire HTTPS, inoltrare il traffico al container WordPress, e servire asset statici. La configurazione del reverse proxy è esterna a questo scaffold di base.

Comandi utili sul server di produzione:

- `make prod-down`: Ferma e rimuove i container (i volumi persistono).
- `make prod-logs`: Mostra i log.
- `make prod-shell-wp`: Apre una shell nel container WordPress di produzione.

## Struttura dei volumi

### Sviluppo:

- `db_data_dev`: Dati del database MariaDB per l'ambiente di sviluppo.
- `wp_uploads_dev`: File caricati (media) per l'ambiente di sviluppo.
- `src/wp-content`: Mappato direttamente per lo sviluppo live di temi/plugin.

### Produzione:

- `db_data_prod`: Dati del database MariaDB per l'ambiente di produzione.
- `wp_uploads_prod`: File caricati (media) per l'ambiente di produzione.
- Temi e plugin sono inclusi nell'immagine Docker, non mappati da un volume di codice sorgente.

## Integrazione con Traefik (Produzione)

Questo scaffold è preconfigurato per integrarsi con [Traefik](https://traefik.io/traefik/) come reverse proxy in produzione. Le etichette (labels) Docker necessarie sono incluse nel file `docker-compose.yml` per il servizio `wordpress`.

### Prerequisiti per Traefik:

1.  **Traefik in Esecuzione:** Devi avere un'istanza di Traefik v2+ in esecuzione e configurata per ascoltare le configurazioni Docker.
2.  **Rete Docker Condivisa:**
    - Il container WordPress e il container Traefik devono condividere una rete Docker. Questo scaffold assume una rete chiamata `traefik-public` (puoi cambiarla tramite la variabile `TRAEFIK_NETWORK` nel file `.env`).
    - Questa rete deve essere creata come `external`. Se non esiste, creala con:
      ```bash
      docker network create traefik-public # o il nome che hai scelto in TRAEFIK_NETWORK
      ```
    - Assicurati che il tuo container Traefik sia connesso a questa stessa rete.
3.  **Entrypoints Traefik:**
    - Le etichette usano gli entrypoint `web` (per HTTP) e `websecure` (per HTTPS). Verifica che questi nomi corrispondano alla tua configurazione di Traefik.
4.  **Certificate Resolver:**
    - Imposta la variabile `TRAEFIK_CERTRESOLVER` nel tuo file `.env` con il nome del tuo risolutore di certificati configurato in Traefik (es. `letsencrypt`, `le`, `myresolver`) per la generazione automatica di certificati SSL.

### Configurazione:

- Il file `docker-compose.yml` (usato in produzione) configurerà automaticamente:
  - Un router HTTP che reindirizza a HTTPS.
  - Un router HTTPS per il tuo `SITE_DOMAIN` con TLS abilitato tramite il `TRAEFIK_CERTRESOLVER` specificato.
  - Un servizio Traefik che punta alla porta 80 interna del container WordPress.
- Il servizio WordPress **non espone porte direttamente all'host** nel `docker-compose.yml` di produzione, poiché Traefik gestirà tutto il traffico in ingresso.

### Variabili `.env` Rilevanti per Traefik:

- `SITE_DOMAIN`: Il dominio per cui Traefik creerà le rotte.
- `SITE_SCHEME`: Dovrebbe essere `https` quando si usa Traefik per SSL.
- `TRAEFIK_CERTRESOLVER`: Il nome del tuo risolutore di certificati in Traefik.
- `TRAEFIK_NETWORK`: (Opzionale) Nome della rete Docker condivisa con Traefik (default: `traefik_public`).

Quando deployi in produzione con `make prod-up` (o `docker compose -f docker-compose.yml up -d`), Traefik dovrebbe rilevare automaticamente il nuovo servizio WordPress e configurare il routing e SSL.
