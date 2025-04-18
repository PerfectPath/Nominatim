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

# Initialize Nominatim if not already done
if [ ! -f /var/lib/postgresql/12/main/import-finished ]; then
    echo "Setting up permissions..."
    # Ensure nominatim user owns required directories
    chown -R nominatim:nominatim /nominatim
    chown -R nominatim:nominatim /app
    
    echo "Importing OSM data..."
    # Run import as nominatim user with proper environment
    su - nominatim -c "source ~/.bashrc && nominatim import --osm-file $PBF_PATH"
    
    touch /var/lib/postgresql/12/main/import-finished
    echo "OSM data import completed"
fi

# Remove stale pid if it exists
if [ -f /var/run/apache2/apache2.pid ]; then
    rm /var/run/apache2/apache2.pid
fi

# Start Apache in foreground
echo "Starting Apache..."
exec /usr/sbin/apache2ctl -DFOREGROUND