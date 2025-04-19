#!/bin/bash
set -e

# Start PostgreSQL
service postgresql start

# Wait for PostgreSQL to be ready
until pg_isready -h localhost; do
    echo "Waiting for PostgreSQL to start..."
    sleep 2
done
echo "PostgreSQL is ready"

# Initialize database users and permissions
echo "Initializing database users and permissions..."
/docker-entrypoint-initdb.d/init-db.sh

# Ensure PostgreSQL directories exist with correct permissions
mkdir -p /var/lib/postgresql/12/main
chown -R postgres:postgres /var/lib/postgresql

# Initialize PostgreSQL if needed
if [ ! -f "/var/lib/postgresql/12/main/PG_VERSION" ] || [ "$FORCE_DB_INIT" = "true" ]; then
    echo "PostgreSQL data directory needs initialization (FORCE_DB_INIT=$FORCE_DB_INIT)"
    
    if [ "$FORCE_DB_INIT" = "true" ]; then
        echo "Forcing reinitialization of PostgreSQL data..."
        rm -rf /var/lib/postgresql/12/main/*
    fi

    # Initialize PostgreSQL data directory
    su - postgres -c "initdb -D /var/lib/postgresql/12/main"
    echo "Setting up permissions..."
    # Ensure nominatim user owns required directories
    chown -R nominatim:nominatim /nominatim
    chown -R nominatim:nominatim /app
    
    echo "Importing OSM data..."
    # Import the data directly (nominatim will create the schema)
    su - nominatim -c "source ~/.bashrc && \
        nominatim import --osm-file $OSM_DATA_PATH --project-dir /app/nominatim-project --no-download-updates && \
        nominatim index --project-dir /app/nominatim-project && \
        nominatim refresh --project-dir /app/nominatim-project"
    
    # Mark initialization as complete
    touch /osm/cl/postgresql/nominatim-import-finished
    echo "PostgreSQL data and OSM import completed"
else
    echo "Using existing PostgreSQL data directory"
fi

# Ensure correct permissions
chown -R postgres:postgres /osm/cl/postgresql
chmod 700 /osm/cl/postgresql

# Remove stale pid if it exists
if [ -f /var/run/apache2/apache2.pid ]; then
    rm /var/run/apache2/apache2.pid
fi

# Start Apache in foreground
echo "Starting Apache..."
exec /usr/sbin/apache2ctl -DFOREGROUND