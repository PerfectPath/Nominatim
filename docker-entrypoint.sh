#!/bin/bash
set -e

# Configurar colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes informativos
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Función para imprimir mensajes de éxito
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Función para imprimir mensajes de advertencia
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Función para imprimir mensajes de error
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar archivo OSM
if [ ! -f /app/data/chile-latest.osm.pbf ]; then
    warning "Archivo OSM no encontrado, descargando..."
    wget -q https://download.geofabrik.de/south-america/chile-latest.osm.pbf -O /app/data/chile-latest.osm.pbf
    if [ $? -eq 0 ]; then
        success "Archivo OSM descargado correctamente"
    else
        error "Error al descargar el archivo OSM"
        exit 1
    fi
else
    info "Archivo OSM encontrado en /app/data/chile-latest.osm.pbf"
fi

# Verificar si PostgreSQL está inicializado
if [ ! -d /var/lib/postgresql/14/main ]; then
    info "Inicializando PostgreSQL..."
    mkdir -p /var/lib/postgresql/14/main
    chown -R postgres:postgres /var/lib/postgresql/14/main
    su - postgres -c "/usr/lib/postgresql/14/bin/initdb -D /var/lib/postgresql/14/main"
    success "PostgreSQL inicializado correctamente"
fi

# Verificar permisos de PostgreSQL
chown -R postgres:postgres /var/lib/postgresql/14/main
chmod 700 /var/lib/postgresql/14/main

# Verificar si la base de datos Nominatim existe
su - postgres -c "pg_isready" || true
su - postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw nominatim" || {
    info "Creando base de datos Nominatim..."
    su - postgres -c "createuser -s nominatim"
    su - postgres -c "createdb -E UTF8 -O nominatim nominatim"
    su - postgres -c "psql -d nominatim -c 'CREATE EXTENSION postgis;'"
    su - postgres -c "psql -d nominatim -c 'CREATE EXTENSION hstore;'"
    success "Base de datos Nominatim creada correctamente"
}

# Verificar si Nominatim está configurado
if [ ! -f /app/nominatim-project/settings/local.php ]; then
    warning "Configuración de Nominatim no encontrada, configurando..."
    mkdir -p /app/nominatim-project/settings
    echo "<?php
    @define('CONST_Database_DSN', 'pgsql:host=localhost;port=5432;dbname=nominatim;user=nominatim;password=nominatim');
    @define('CONST_Website_BaseURL', '/');
    @define('CONST_Osm_Binary_Path', '/usr/local/bin/');
    " > /app/nominatim-project/settings/local.php
    success "Nominatim configurado correctamente"
fi

# Verificar permisos de Nominatim
chown -R www-data:www-data /app/nominatim-project

# Asegurarse de que el archivo pg_hba.conf tiene los permisos correctos
if [ -f /etc/postgresql/14/main/pg_hba.conf ]; then
    info "Configurando permisos para pg_hba.conf..."
    chown postgres:postgres /etc/postgresql/14/main/pg_hba.conf
    chmod 640 /etc/postgresql/14/main/pg_hba.conf
    success "Permisos configurados correctamente"
fi

# Iniciar servicios
info "Iniciando servicios..."
exec "$@"
