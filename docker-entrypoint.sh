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
if [ ! -d /var/lib/postgresql/12/main ]; then
    info "Inicializando PostgreSQL..."
    mkdir -p /var/lib/postgresql/12/main
    chown -R postgres:postgres /var/lib/postgresql/12/main
    su - postgres -c "/usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main"
    success "PostgreSQL inicializado correctamente"
fi

# Verificar permisos de PostgreSQL
chown -R postgres:postgres /var/lib/postgresql/12/main
chmod 700 /var/lib/postgresql/12/main

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

# Configurar PostgreSQL para usar trust en lugar de peer
info "Configurando PostgreSQL para usar autenticación trust..."

# Verificar si el archivo pg_hba_custom.conf existe
if [ -f /nominatim/pg_hba_custom.conf ]; then
    info "Copiando archivo pg_hba_custom.conf a PostgreSQL..."
    cp /nominatim/pg_hba_custom.conf /etc/postgresql/12/main/pg_hba.conf
    chown postgres:postgres /etc/postgresql/12/main/pg_hba.conf
    chmod 640 /etc/postgresql/12/main/pg_hba.conf
    
    # Reiniciar PostgreSQL para aplicar la configuración
    info "Reiniciando PostgreSQL para aplicar la configuración..."
    service postgresql restart
    success "PostgreSQL configurado correctamente"
else
    warning "Archivo pg_hba_custom.conf no encontrado, usando configuración predeterminada"
    
    # Crear archivo pg_hba.conf directamente
    cat > /etc/postgresql/12/main/pg_hba.conf << EOF
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5

# IPv6 local connections:
host    all             all             ::1/128                 md5
EOF
    chown postgres:postgres /etc/postgresql/12/main/pg_hba.conf
    chmod 640 /etc/postgresql/12/main/pg_hba.conf
    
    # Reiniciar PostgreSQL para aplicar la configuración
    info "Reiniciando PostgreSQL para aplicar la configuración..."
    service postgresql restart
    success "PostgreSQL configurado correctamente"
fi

# Iniciar servicios
info "Iniciando servicios..."
exec "$@"
