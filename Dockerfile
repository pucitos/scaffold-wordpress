# Scegli un'immagine WordPress di base specifica
FROM wordpress:6.8-php8.4-apache 

# Argomento per l'ambiente (default: production)
ARG APP_ENV=production

# Argomenti di build per UID e GID dell'host, e nomi per il nuovo utente/gruppo
# Usati solo se APP_ENV=development
ARG TARGET_UID=1000
ARG TARGET_GID=1000
ARG DEV_USER=devuser
ARG DEV_GROUP=devgroup

# Variabili d'ambiente per memorizzare i nomi effettivi dell'utente/gruppo da usare
# Inizializzate con i default per produzione (www-data)
ENV ACTUAL_APACHE_USER=www-data
ENV ACTUAL_APACHE_GROUP=www-data

# Stampa il valore di APP_ENV ricevuto e poi esegui la logica condizionale
RUN echo ">>>> DOCKERFILE DEBUG: Valore di APP_ENV ricevuto: [${APP_ENV}] <<<<" && \
    echo ">>>> DOCKERFILE DEBUG: Valore di TARGET_UID ricevuto: [${TARGET_UID}] <<<<" && \
    echo ">>>> DOCKERFILE DEBUG: Valore di TARGET_GID ricevuto: [${TARGET_GID}] <<<<" && \
    if [ "${APP_ENV}" = "development" ]; then \
    echo ">>>> DOCKERFILE DEBUG: CONDIZIONE IF SODDISFATTA - Esecuzione blocco sviluppo. <<<<"; \
    # Variabili temporanee per i nomi utente/gruppo di sviluppo
    TEMP_DEV_USER=${DEV_USER}; \
    TEMP_DEV_GROUP=${DEV_GROUP}; \
    # Crea il gruppo se non esiste un gruppo con TARGET_GID
    if ! getent group ${TARGET_GID} > /dev/null; then \
    echo ">>>> DOCKERFILE DEBUG: Creazione gruppo ${TEMP_DEV_GROUP} con GID ${TARGET_GID}. <<<<"; \
    groupadd -g ${TARGET_GID} ${TEMP_DEV_GROUP}; \
    else \
    EXISTING_GROUP_NAME=$(getent group ${TARGET_GID} | cut -d: -f1); \
    if [ "${EXISTING_GROUP_NAME}" != "${TEMP_DEV_GROUP}" ]; then \
    echo ">>>> DOCKERFILE DEBUG: Gruppo con GID ${TARGET_GID} esiste come '${EXISTING_GROUP_NAME}'. Uso questo nome. <<<<"; \
    TEMP_DEV_GROUP=${EXISTING_GROUP_NAME}; \
    fi; \
    fi; \
    # Crea l'utente se non esiste un utente con TARGET_UID
    if ! getent passwd ${TARGET_UID} > /dev/null; then \
    echo ">>>> DOCKERFILE DEBUG: Creazione utente ${TEMP_DEV_USER} con UID ${TARGET_UID} e gruppo ${TEMP_DEV_GROUP}. <<<<"; \
    useradd --shell /bin/bash -u ${TARGET_UID} -g ${TEMP_DEV_GROUP} -o -m ${TEMP_DEV_USER}; \
    else \
    EXISTING_USER_NAME=$(getent passwd ${TARGET_UID} | cut -d: -f1); \
    if [ "${EXISTING_USER_NAME}" != "${TEMP_DEV_USER}" ]; then \
    echo ">>>> DOCKERFILE DEBUG: Utente con UID ${TARGET_UID} esiste come '${EXISTING_USER_NAME}'. Uso questo nome. <<<<"; \
    TEMP_DEV_USER=${EXISTING_USER_NAME}; \
    fi; \
    echo ">>>> DOCKERFILE DEBUG: Modifica gruppo per utente esistente ${TEMP_DEV_USER} a ${TEMP_DEV_GROUP}. <<<<"; \
    usermod -g ${TEMP_DEV_GROUP} ${TEMP_DEV_USER}; \
    fi; \
    # Imposta le variabili d'ambiente per Apache con i nomi utente/gruppo di sviluppo
    export ACTUAL_APACHE_USER=${TEMP_DEV_USER}; \
    export ACTUAL_APACHE_GROUP=${TEMP_DEV_GROUP}; \
    # Modifica /etc/apache2/envvars per usare l'utente/gruppo di sviluppo
    echo ">>>> DOCKERFILE DEBUG: Modifica /etc/apache2/envvars per usare utente=${ACTUAL_APACHE_USER} e gruppo=${ACTUAL_APACHE_GROUP}. <<<<"; \
    sed -i "s/^export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=${ACTUAL_APACHE_USER}/g" /etc/apache2/envvars && \
    sed -i "s/^export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=${ACTUAL_APACHE_GROUP}/g" /etc/apache2/envvars; \
    else \
    echo ">>>> DOCKERFILE DEBUG: CONDIZIONE IF NON SODDISFATTA - Esecuzione blocco produzione (default). <<<<"; \
    echo ">>>> DOCKERFILE DEBUG: Apache userà www-data. <<<<"; \
    fi

# Copia il contenuto di wp-content
COPY ./src/wp-content/ /var/www/html/wp-content/
