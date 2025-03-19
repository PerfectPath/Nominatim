FROM mediagis/nominatim:4.0

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar wget
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Configurar directorios
WORKDIR /app

# Descargar archivo OSM de Chile directamente a la ubicación esperada por el script de inicio
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /nominatim/data.osm.pbf

# Configurar variables de entorno para Nominatim
ENV PBF_PATH=/nominatim/data.osm.pbf
ENV REPLICATION_URL=https://download.geofabrik.de/south-america/chile-updates/
ENV NOMINATIM_PASSWORD=password123
ENV NOMINATIM_DATABASE=nominatim
ENV NOMINATIM_DATABASE_DSN="pgsql:dbname=${NOMINATIM_DATABASE};user=nominatim;password=${NOMINATIM_PASSWORD}"

# Copiar archivos de configuración si existen
COPY ./settings/local.php /app/nominatim-project/settings/local.php

# Exponer puerto
EXPOSE 8080

# Usar el script de entrada predeterminado de la imagen base
ENTRYPOINT ["/app/start.sh"]
