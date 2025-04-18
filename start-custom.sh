#!/bin/bash
set -e

# Start PostgreSQL
service postgresql start

# Wait for PostgreSQL and initialize database
/app/wait-for-postgres.sh

# Start Apache in foreground
if [ -f /var/run/apache2/apache2.pid ]; then
    rm /var/run/apache2/apache2.pid
fi

# Initialize Nominatim if not already done
if [ ! -f /var/lib/postgresql/12/main/import-finished ]; then
    sudo -u nominatim nominatim import --osm-file $PBF_PATH
    touch /var/lib/postgresql/12/main/import-finished
fi

# Start Apache in foreground
/usr/sbin/apache2ctl -DFOREGROUND