FROM mediagis/nominatim:4.0

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Configurar directorios
WORKDIR /app
RUN mkdir -p /app/data

# Descargar archivo OSM de Chile
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /app/data/chile-latest.osm.pbf

# Configurar variables de entorno para Nominatim
ENV PBF_URL=/app/data/chile-latest.osm.pbf
ENV REPLICATION_URL=https://download.geofabrik.de/south-america/chile-updates/
ENV NOMINATIM_PASSWORD=password123
ENV NOMINATIM_DATABASE=nominatim
ENV NOMINATIM_DATABASE_DSN="pgsql:dbname=${NOMINATIM_DATABASE};user=nominatim;password=${NOMINATIM_PASSWORD}"

# Copiar archivos de configuración
COPY ./settings/local.php /app/nominatim-project/settings/local.php

# Exponer puerto
EXPOSE 8080

# Usar el script de entrada predeterminado de la imagen base
ENTRYPOINT ["/app/start.sh"]
