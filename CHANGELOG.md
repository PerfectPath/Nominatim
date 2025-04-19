# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-04-18
### Added
- Persistent volume support for PostgreSQL data
- FORCE_DB_INIT environment variable to control database initialization
- Database initialization check to skip import when data exists

## [0.2.0] - 2025-04-18
### Changed
- Disabled restrictive Apache security modules (mod_security, mod_reqtimeout)
- Added CORS headers to allow all origins
- Simplified Apache configuration for internal network usage

## [0.1.0] - 2025-04-10
### Added
- Initial setup with Nominatim 4.0
- PostgreSQL integration
- Chile OSM data import
- Basic geocoding functionality
- Docker configuration