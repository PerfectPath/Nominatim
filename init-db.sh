#!/bin/bash
set -e

# Create nominatim user if it doesn't exist
sudo -u postgres psql -c "DO \$\$ BEGIN CREATE USER nominatim WITH SUPERUSER PASSWORD 'nominatim'; EXCEPTION WHEN DUPLICATE_OBJECT THEN RAISE NOTICE 'User already exists'; END \$\$;"

# Create www-data user if it doesn't exist
sudo -u postgres psql -c "DO \$\$ BEGIN CREATE USER \"www-data\" WITH PASSWORD 'nominatim'; EXCEPTION WHEN DUPLICATE_OBJECT THEN RAISE NOTICE 'User already exists'; END \$\$;"

# Grant necessary permissions
sudo -u postgres psql -c "ALTER USER nominatim CREATEDB;"
sudo -u postgres psql -c "GRANT nominatim TO \"www-data\";"

# Create and configure nominatim database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS nominatim;"
sudo -u postgres createdb -O nominatim nominatim

# Initialize database schema
sudo -u postgres psql -d nominatim -c "CREATE EXTENSION IF NOT EXISTS postgis;"
sudo -u postgres psql -d nominatim -c "CREATE EXTENSION IF NOT EXISTS hstore;"
sudo -u postgres psql -d nominatim -c "ALTER DATABASE nominatim SET postgis.enable_outdb_rasters TO True;"
sudo -u postgres psql -d nominatim -c "ALTER DATABASE nominatim SET postgis.gdal_enabled_drivers TO 'ENABLE_ALL';"

# Initialize Nominatim database structure
echo "Initializing Nominatim database structure..."
su - nominatim -c "source ~/.bashrc && nominatim create-functions --project-dir /app/nominatim-project"

# Set permissions
sudo -u postgres psql -d nominatim -c "GRANT ALL PRIVILEGES ON DATABASE nominatim TO nominatim;"
sudo -u postgres psql -d nominatim -c "GRANT CONNECT ON DATABASE nominatim TO \"www-data\";"
sudo -u postgres psql -d nominatim -c "GRANT USAGE ON SCHEMA public TO \"www-data\";"
sudo -u postgres psql -d nominatim -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO \"www-data\";"