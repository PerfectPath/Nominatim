FROM mediagis/nominatim:4.0

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar wget y herramientas de PostgreSQL
RUN apt-get update && \
    apt-get install -y wget postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Crear archivo con comandos SQL para configurar usuarios
RUN echo "CREATE USER www-data WITH PASSWORD 'nominatim';" > /docker-entrypoint-initdb.d/setup-users.sql && \
    echo "GRANT nominatim TO www-data;" >> /docker-entrypoint-initdb.d/setup-users.sql

# Configurar directorios
WORKDIR /app

# Descargar archivo OSM de Chile directamente a la ubicación esperada por el script de inicio
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /nominatim/data.osm.pbf

# Descargar el archivo country_grid necesario para la funcionalidad de búsqueda
RUN mkdir -p /app/data && wget -q https://nominatim.org/data/country_grid.sql.gz -O /app/data/country_osm_grid.sql.gz

# Configurar variables de entorno para Nominatim
ENV PBF_PATH=/nominatim/data.osm.pbf
ENV REPLICATION_URL=https://download.geofabrik.de/south-america/chile-updates/
ENV NOMINATIM_PASSWORD=nominatim
ENV NOMINATIM_DATABASE=nominatim
ENV NOMINATIM_DATABASE_DSN="pgsql:host=localhost;dbname=${NOMINATIM_DATABASE};user=nominatim;password=${NOMINATIM_PASSWORD}"
ENV POSTGRES_PASSWORD=nominatim

# Copiar archivos de configuración si existen
COPY ./settings/local.php /app/nominatim-project/settings/local.php
# Copiar configuración personalizada de PostgreSQL
COPY ./pg_hba_custom.conf /nominatim/pg_hba_custom.conf

# Exponer puerto
EXPOSE 8080

# Usar el script de entrada predeterminado de la imagen base
ENTRYPOINT ["/app/start.sh"]
