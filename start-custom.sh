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

# Function to check if database is initialized
check_db_initialized() {
    su - postgres -c "psql -lqt" | cut -d \| -f 1 | grep -qw nominatim
    return $?
}

# Initialize Nominatim if needed
if [ "$FORCE_DB_INIT" = "true" ] || ! check_db_initialized; then
    echo "Database initialization required (FORCE_DB_INIT=$FORCE_DB_INIT)"
    echo "Setting up permissions..."
    # Ensure nominatim user owns required directories
    chown -R nominatim:nominatim /nominatim
    chown -R nominatim:nominatim /app
    
    echo "Importing OSM data..."
    # Import the data directly (nominatim will create the schema)
    su - nominatim -c "source ~/.bashrc && \
        nominatim import --osm-file $PBF_PATH --project-dir /app/nominatim-project && \
        nominatim index --project-dir /app/nominatim-project && \
        nominatim refresh --project-dir /app/nominatim-project"
    
    # Mark initialization as complete
    touch /var/lib/postgresql/data/import-finished
    echo "OSM data import completed"
else
    echo "Database already initialized, skipping import"
fi

# Remove stale pid if it exists
if [ -f /var/run/apache2/apache2.pid ]; then
    rm /var/run/apache2/apache2.pid
fi

# Start Apache in foreground
echo "Starting Apache..."
exec /usr/sbin/apache2ctl -DFOREGROUND