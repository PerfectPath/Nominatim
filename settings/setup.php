<?php
// Database connection
@define('CONST_Database_DSN', 'pgsql:host=localhost;port=5432;dbname=nominatim;user=nominatim;password=nominatim');
@define('CONST_Database_Web_User', 'www-data');
@define('CONST_Database_Web_Password', 'nominatim');

// Database setup
@define('CONST_Database_Module_Path', '/usr/lib/postgresql/12/lib/');
@define('CONST_Postgresql_Version', '12');
@define('CONST_Postgis_Version', '3');

// Import settings
@define('CONST_Osm2pgsql_Binary', '/usr/bin/osm2pgsql');
@define('CONST_Import_Style', 'full');
@define('CONST_Import_Style_Local', CONST_Import_Style);
@define('CONST_Import_Node_Cache_Size', '2500');
@define('CONST_Import_Cache_Flush_Memory', '50');

// Website settings
@define('CONST_Website_BaseURL', '/');

// Logging
@define('CONST_Log_DB', true);
@define('CONST_Log_File', '/app/nominatim-project/nominatim.log');

// Allow database creation during import
@define('CONST_Skip_Database_Creation', true);