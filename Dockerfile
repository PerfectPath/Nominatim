FROM mediagis/nominatim:4.0

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar herramientas necesarias
RUN apt-get update && \
    apt-get install -y \
    wget \
    postgresql-client \
    sudo \
    postgresql-12-postgis-3 \
    postgresql-12-postgis-3-scripts \
    osm2pgsql \
    osmium-tool \
    && rm -rf /var/lib/apt/lists/* && \
    # Crear usuario y grupo nominatim
    addgroup --system nominatim && \
    adduser --system --ingroup nominatim --home /home/nominatim --shell /bin/bash nominatim && \
    # Agregar nominatim al grupo sudo
    adduser nominatim sudo && \
    # Permitir a nominatim usar sudo sin contraseña
    echo "nominatim ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nominatim && \
    # Asegurar que nominatim tenga acceso a los comandos necesarios
    echo 'export PATH="/usr/local/bin:$PATH"' >> /home/nominatim/.bashrc && \
    # Dar propiedad de directorios importantes
    chown -R nominatim:nominatim /home/nominatim

# Crear script de inicialización de PostgreSQL
COPY ./init-db.sh /docker-entrypoint-initdb.d/init-db.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh

# Configurar directorios y volumen para PostgreSQL y datos OSM
WORKDIR /app
RUN mkdir -p /app/nominatim-project && \
    mkdir -p /osm/cl/postgresql && \
    mkdir -p /osm/cl/data && \
    chown -R nominatim:nominatim /app/nominatim-project && \
    chown -R postgres:postgres /osm/cl/postgresql && \
    chown -R nominatim:nominatim /osm/cl/data

# Mover y configurar directorio de datos de PostgreSQL
RUN service postgresql stop && \
    if [ -d "/var/lib/postgresql/12/main" ]; then \
        mv /var/lib/postgresql/12/main/* /osm/cl/postgresql/ 2>/dev/null || true; \
    fi && \
    rm -rf /var/lib/postgresql/12/main && \
    ln -s /osm/cl/postgresql /var/lib/postgresql/12/main

# Variable para control de inicialización
ENV FORCE_DB_INIT=false

# Configurar la ubicación del archivo OSM
ENV OSM_DATA_PATH=/osm/cl/data/chile-latest.osm.pbf

# Descargar archivo OSM
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O $OSM_DATA_PATH

# Descargar el archivo country_grid necesario para la funcionalidad de búsqueda
RUN mkdir -p /app/data && wget -q https://nominatim.org/data/country_grid.sql.gz -O /app/data/country_osm_grid.sql.gz

# Configurar variables de entorno para Nominatim
ENV PBF_PATH=/nominatim/data.osm.pbf
ENV REPLICATION_URL=https://download.geofabrik.de/south-america/chile-updates/
ENV NOMINATIM_DATABASE_DSN="pgsql:host=localhost;dbname=nominatim;user=www-data;password=nominatim"

# Crear script para esperar a PostgreSQL
RUN echo '#!/bin/bash' > /app/wait-for-postgres.sh && \
    echo 'until pg_isready -h localhost; do' >> /app/wait-for-postgres.sh && \
    echo '  echo "Waiting for PostgreSQL to start..."' >> /app/wait-for-postgres.sh && \
    echo '  sleep 2' >> /app/wait-for-postgres.sh && \
    echo 'done' >> /app/wait-for-postgres.sh && \
    echo 'echo "PostgreSQL is ready, running database initialization..."' >> /app/wait-for-postgres.sh && \
    echo '/docker-entrypoint-initdb.d/init-db.sh' >> /app/wait-for-postgres.sh && \
    chmod +x /app/wait-for-postgres.sh

# Copiar y configurar archivos de configuración
RUN mkdir -p /app/nominatim-project/settings /app/nominatim-project/module
COPY ./settings/setup.php /app/nominatim-project/settings/setup.php
COPY ./pg_hba_custom.conf /nominatim/pg_hba_custom.conf
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Configurar Apache
RUN a2dismod security2 reqtimeout && \
    a2enmod headers && \
    # Asegurarse que los módulos estén disponibles
    if [ -f /etc/apache2/mods-available/security2.load ]; then rm /etc/apache2/mods-available/security2.load; fi && \
    if [ -f /etc/apache2/mods-available/reqtimeout.load ]; then rm /etc/apache2/mods-available/reqtimeout.load; fi
RUN chown -R nominatim:nominatim /app/nominatim-project && \
    chmod 644 /app/nominatim-project/settings/setup.php && \
    chmod 755 /app/nominatim-project/module && \
    touch /app/nominatim-project/nominatim.log && \
    chown nominatim:nominatim /app/nominatim-project/nominatim.log && \
    chmod 664 /app/nominatim-project/nominatim.log

# Exponer puerto
EXPOSE 8080

# Copiar y configurar script de inicio personalizado
COPY ./start-custom.sh /app/start-custom.sh
RUN chmod +x /app/start-custom.sh

# Usar nuestro script de inicio personalizado
ENTRYPOINT ["/app/start-custom.sh"]
