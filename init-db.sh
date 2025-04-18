#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create nominatim user with all necessary permissions
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nominatim') THEN
            CREATE USER nominatim WITH SUPERUSER PASSWORD 'nominatim';
        END IF;
    END
    \$\$;

    -- Create www-data user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'www-data') THEN
            CREATE USER "www-data" WITH PASSWORD 'nominatim';
        END IF;
    END
    \$\$;

    -- Grant necessary permissions
    ALTER USER nominatim CREATEDB;
    GRANT nominatim TO "www-data";
    
    -- Create nominatim database if it doesn't exist
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nominatim') THEN
            CREATE DATABASE nominatim OWNER nominatim;
        END IF;
    END
    \$\$;
EOSQL

# Grant permissions on the nominatim database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "nominatim" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE nominatim TO nominatim;
    GRANT CONNECT ON DATABASE nominatim TO "www-data";
    GRANT USAGE ON SCHEMA public TO "www-data";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "www-data";
EOSQL