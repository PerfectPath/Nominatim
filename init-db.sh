#!/bin/bash
set -e

# Create nominatim user if it doesn't exist
sudo -u postgres psql -c "DO \$\$ BEGIN CREATE USER nominatim WITH SUPERUSER PASSWORD 'nominatim'; EXCEPTION WHEN DUPLICATE_OBJECT THEN RAISE NOTICE 'User already exists'; END \$\$;"

# Create www-data user if it doesn't exist
sudo -u postgres psql -c "DO \$\$ BEGIN CREATE USER \"www-data\" WITH PASSWORD 'nominatim'; EXCEPTION WHEN DUPLICATE_OBJECT THEN RAISE NOTICE 'User already exists'; END \$\$;"

# Grant necessary permissions
sudo -u postgres psql -c "ALTER USER nominatim CREATEDB SUPERUSER;"
sudo -u postgres psql -c "GRANT nominatim TO \"www-data\";"

# Let nominatim handle database creation and schema setup