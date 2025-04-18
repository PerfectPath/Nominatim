FROM mediagis/nominatim:4.0

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar wget y herramientas de PostgreSQL
RUN apt-get update && \
    apt-get install -y wget postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Crear script de inicialización de PostgreSQL
COPY ./init-db.sh /docker-entrypoint-initdb.d/init-db.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh

# Configurar directorios
WORKDIR /app

# Descargar archivo OSM de Chile directamente a la ubicación esperada por el script de inicio
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /nominatim/data.osm.pbf

# Descargar el archivo country_grid necesario para la funcionalidad de búsqueda
RUN mkdir -p /app/data && wget -q https://nominatim.org/data/country_grid.sql.gz -O /app/data/country_osm_grid.sql.gz

# Configurar variables de entorno para Nominatim y PostgreSQL
ENV PBF_PATH=/nominatim/data.osm.pbf
ENV REPLICATION_URL=https://download.geofabrik.de/south-america/chile-updates/
ENV NOMINATIM_PASSWORD=nominatim
ENV NOMINATIM_DATABASE=nominatim
ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=postgres
ENV POSTGRES_PASSWORD=nominatim
ENV NOMINATIM_DATABASE_DSN="pgsql:host=localhost;dbname=${NOMINATIM_DATABASE};user=www-data;password=${NOMINATIM_PASSWORD}"

# Crear script para esperar a PostgreSQL
RUN echo '#!/bin/bash' > /app/wait-for-postgres.sh && \
    echo 'until pg_isready -h localhost; do' >> /app/wait-for-postgres.sh && \
    echo '  echo "Waiting for PostgreSQL to start..."' >> /app/wait-for-postgres.sh && \
    echo '  sleep 2' >> /app/wait-for-postgres.sh && \
    echo 'done' >> /app/wait-for-postgres.sh && \
    echo 'echo "PostgreSQL is ready, running database initialization..."' >> /app/wait-for-postgres.sh && \
    echo '/docker-entrypoint-initdb.d/init-db.sh' >> /app/wait-for-postgres.sh && \
    chmod +x /app/wait-for-postgres.sh

# Copiar archivos de configuración si existen
COPY ./settings/local.php /app/nominatim-project/settings/local.php
# Copiar configuración personalizada de PostgreSQL
COPY ./pg_hba_custom.conf /nominatim/pg_hba_custom.conf

# Exponer puerto
EXPOSE 8080

# Copiar y configurar script de inicio personalizado
COPY ./start-custom.sh /app/start-custom.sh
RUN chmod +x /app/start-custom.sh

# Usar nuestro script de inicio personalizado
ENTRYPOINT ["/app/start-custom.sh"]
