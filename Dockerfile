FROM ubuntu:22.04 AS build

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    g++ \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libexpat1-dev \
    zlib1g-dev \
    libbz2-dev \
    libpq-dev \
    libproj-dev \
    postgresql-server-dev-14 \
    postgresql-14-postgis-3 \
    postgresql-contrib \
    postgresql-14-postgis-3-scripts \
    php \
    php-pgsql \
    php-intl \
    php-cli \
    php-curl \
    php-mbstring \
    php-xml \
    python3-dev \
    python3-pip \
    python3-psycopg2 \
    python3-tidylib \
    git \
    wget \
    osmium-tool \
    && rm -rf /var/lib/apt/lists/*

# Configurar directorios
WORKDIR /app
RUN mkdir -p /app/data

# Descargar archivo OSM de Chile
RUN wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /app/data/chile-latest.osm.pbf

# Clonar el código fuente de Nominatim (versión específica)
RUN git clone --recursive https://github.com/osm-search/Nominatim.git /app/Nominatim && \
    cd /app/Nominatim && \
    git checkout v4.0.0

# Compilar e instalar Nominatim
WORKDIR /app/Nominatim
RUN mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) VERBOSE=1 && \
    make install

# Configurar Nominatim
RUN mkdir -p /app/nominatim-project && \
    /app/Nominatim/build/utils/setup.php --osm-file /app/data/chile-latest.osm.pbf \
    --all --osm2pgsql-cache 1000 --project-dir /app/nominatim-project

FROM ubuntu:22.04 AS app

# Evitar interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias de tiempo de ejecución
RUN apt-get update && apt-get install -y \
    postgresql-14 \
    postgresql-14-postgis-3 \
    postgresql-14-postgis-3-scripts \
    postgresql-contrib \
    php \
    php-pgsql \
    php-intl \
    php-fpm \
    nginx \
    supervisor \
    python3 \
    python3-psycopg2 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Configurar directorios
WORKDIR /app
RUN mkdir -p /app/data

# Copiar archivos de la etapa de build
COPY --from=build /app/data/chile-latest.osm.pbf /app/data/
COPY --from=build /app/nominatim-project /app/nominatim-project
COPY --from=build /usr/local/lib/nominatim /usr/local/lib/nominatim
COPY --from=build /usr/local/bin/nominatim /usr/local/bin/nominatim

# Copiar archivos de configuración
COPY ./settings/env.defaults /app/nominatim-project/.env
COPY ./settings/local.php /app/nominatim-project/settings/local.php

# Configurar Nginx
RUN echo 'server {\n\
    listen 8080;\n\
    root /app/nominatim-project/website;\n\
    index search.php index.php;\n\
    location / {\n\
        try_files $uri $uri/ @php;\n\
    }\n\
    location ~ [^/]\.php(/|$) {\n\
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;\n\
        if (!-f $document_root$fastcgi_script_name) {\n\
            return 404;\n\
        }\n\
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;\n\
        fastcgi_index index.php;\n\
        include fastcgi.conf;\n\
    }\n\
    location @php {\n\
        fastcgi_param SCRIPT_FILENAME $document_root/index.php;\n\
        fastcgi_param PATH_INFO $uri;\n\
        include fastcgi.conf;\n\
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;\n\
    }\n\
}' > /etc/nginx/sites-available/nominatim

RUN ln -s /etc/nginx/sites-available/nominatim /etc/nginx/sites-enabled/ && \
    rm /etc/nginx/sites-enabled/default

# Configurar Supervisor
RUN echo '[supervisord]\n\
nodaemon=true\n\
\n\
[program:nginx]\n\
command=/usr/sbin/nginx -g "daemon off;"\n\
autostart=true\n\
autorestart=true\n\
\n\
[program:php-fpm]\n\
command=/usr/sbin/php-fpm8.1 -F\n\
autostart=true\n\
autorestart=true\n\
\n\
[program:postgresql]\n\
command=/usr/lib/postgresql/14/bin/postgres -D /var/lib/postgresql/14/main\n\
user=postgres\n\
autostart=true\n\
autorestart=true' > /etc/supervisor/conf.d/supervisord.conf

# Script de entrada
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Exponer puerto
EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
