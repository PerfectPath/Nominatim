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

# Configurar directorios
WORKDIR /app
RUN mkdir -p /app/nominatim-project && \
    chown -R nominatim:nominatim /app/nominatim-project

# Descargar archivo OSM de Chile directamente a la ubicación esperada por el script de inicio
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /nominatim/data.osm.pbf

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
