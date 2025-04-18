FROM mediagis/nominatim:4.0

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar wget y herramientas de PostgreSQL
RUN apt-get update && \
    apt-get install -y wget postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Crear script de inicialización de PostgreSQL
RUN mkdir -p /docker-entrypoint-initdb.d && \
    echo '#!/bin/bash' > /docker-entrypoint-initdb.d/setup-users.sh && \
    echo 'psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL' >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "  DO \$\$" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "  BEGIN" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "    CREATE USER www-data WITH PASSWORD 'nominatim';" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "    EXCEPTION WHEN DUPLICATE_OBJECT THEN" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "    RAISE NOTICE 'User already exists';" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "  END" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "  \$\$;" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "  GRANT nominatim TO www-data;" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    echo "EOSQL" >> /docker-entrypoint-initdb.d/setup-users.sh && \
    chmod +x /docker-entrypoint-initdb.d/setup-users.sh

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
ENV POSTGRES_USER=nominatim
ENV POSTGRES_DB=nominatim
ENV POSTGRES_PASSWORD=nominatim
ENV NOMINATIM_DATABASE_DSN="pgsql:host=localhost;dbname=${NOMINATIM_DATABASE};user=www-data;password=${NOMINATIM_PASSWORD}"

# Crear script para ejecutar después de la inicialización de PostgreSQL
RUN mkdir -p /docker-entrypoint-initdb.d/post-init && \
    mv /docker-entrypoint-initdb.d/setup-users.sh /docker-entrypoint-initdb.d/post-init/ && \
    echo '#!/bin/bash' > /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    echo 'until pg_isready -h localhost; do' >> /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    echo '  echo "Waiting for PostgreSQL to start..."' >> /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    echo '  sleep 2' >> /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    echo 'done' >> /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    echo 'echo "PostgreSQL is ready, running user setup..."' >> /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    echo '/docker-entrypoint-initdb.d/post-init/setup-users.sh' >> /docker-entrypoint-initdb.d/wait-and-setup.sh && \
    chmod +x /docker-entrypoint-initdb.d/wait-and-setup.sh

# Copiar archivos de configuración si existen
COPY ./settings/local.php /app/nominatim-project/settings/local.php
# Copiar configuración personalizada de PostgreSQL
COPY ./pg_hba_custom.conf /nominatim/pg_hba_custom.conf

# Exponer puerto
EXPOSE 8080

# Usar el script de entrada predeterminado de la imagen base
ENTRYPOINT ["/app/start.sh"]
