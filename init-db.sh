#!/bin/bash
set -e

# Create nominatim user if it doesn't exist
sudo -u postgres psql -c "DO \$\$ BEGIN CREATE USER nominatim WITH SUPERUSER PASSWORD 'nominatim'; EXCEPTION WHEN DUPLICATE_OBJECT THEN RAISE NOTICE 'User already exists'; END \$\$;"

# Create www-data user if it doesn't exist
sudo -u postgres psql -c "DO \$\$ BEGIN CREATE USER \"www-data\" WITH PASSWORD 'nominatim'; EXCEPTION WHEN DUPLICATE_OBJECT THEN RAISE NOTICE 'User already exists'; END \$\$;"

# Grant necessary permissions
sudo -u postgres psql -c "ALTER USER nominatim CREATEDB;"
sudo -u postgres psql -c "GRANT nominatim TO \"www-data\";"

# Create empty database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS nominatim;"
sudo -u postgres createdb -O nominatim nominatim

# Install required extensions
sudo -u postgres psql -d nominatim -c "CREATE EXTENSION IF NOT EXISTS postgis;"
sudo -u postgres psql -d nominatim -c "CREATE EXTENSION IF NOT EXISTS hstore;"

# Configure database settings
sudo -u postgres psql -d nominatim -c "ALTER DATABASE nominatim SET postgis.enable_outdb_rasters TO True;"
sudo -u postgres psql -d nominatim -c "ALTER DATABASE nominatim SET postgis.gdal_enabled_drivers TO 'ENABLE_ALL';"

# Set basic permissions
sudo -u postgres psql -d nominatim -c "GRANT ALL PRIVILEGES ON DATABASE nominatim TO nominatim;"
sudo -u postgres psql -d nominatim -c "GRANT CONNECT ON DATABASE nominatim TO \"www-data\";"

# Let nominatim handle schema creation and permissions