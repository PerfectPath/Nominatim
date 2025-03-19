# Nominatim Deployment

This directory contains the necessary files to deploy a Nominatim geocoding service.

## Files

- `Dockerfile`: Builds the Nominatim container with the required dependencies and data files
- `docker-compose.yml`: Configuration for local development and testing
- `railway.json`: Configuration for Railway deployment
- `settings/local.php`: Custom settings for Nominatim
- `data/`: Directory containing required data files

## Required Data Files

Nominatim requires specific data files to function properly:

1. **OSM Data**: The Dockerfile is configured to download Chile's OSM data automatically
2. **Country Grid**: The Dockerfile downloads the required `country_osm_grid.sql.gz` file from nominatim.org

## Deploying to Railway

When deploying to Railway, make sure:

1. The service is configured to use port 8080 (specified in `railway.json`)
2. The PostgreSQL database is properly configured and accessible
3. The required data files are downloaded during the build process

## Troubleshooting

### 502 Bad Gateway Error

If you encounter a 502 Bad Gateway error when calling the `/search` endpoint, check:

1. Railway is using the correct port (8080) for the Nominatim API service, not the database port (5432)
2. The `country_osm_grid.sql.gz` file is properly downloaded and available to the service
3. The database connection is properly configured

### Checking Logs

To diagnose issues, check the Railway logs for the service:

```
railway logs
```

Look for any errors related to missing files or database connection issues.
