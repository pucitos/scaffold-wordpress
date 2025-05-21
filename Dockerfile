# Scegli un'immagine WordPress di base specifica
FROM wordpress:6.5-php8.2-apache # O la tua versione PHP/WordPress preferita

# Copia il contenuto di wp-content (temi, plugin) nell'immagine.
# Assicurati che 'src/wp-content/uploads' sia escluso tramite .dockerignore
# o non sia presente nella cartella 'src/wp-content' copiata.
COPY ./src/wp-content/ /var/www/html/wp-content/

# Opzionale: Copia configurazioni PHP personalizzate
# COPY ./config/php/production.ini /usr/local/etc/php/conf.d/zz-production-settings.ini

# L'entrypoint dell'immagine base si occuperà di wp-config.php e permessi.