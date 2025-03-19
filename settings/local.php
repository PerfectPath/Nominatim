<?php
// Nominatim local settings

// Database connection
@define('CONST_Database_DSN', 'pgsql:host=nominatim-db;port=5432;dbname=nominatim;user=nominatim;password=nominatim');

// Website settings
@define('CONST_Website_BaseURL', '/');

// Path to Nominatim binaries
@define('CONST_Osm_Binary_Path', '/usr/local/bin/');

// Path to OSM data file
@define('CONST_Import_Style', 'full');
@define('CONST_Import_Style_Local', CONST_Import_Style);

// Performance settings
@define('CONST_Database_Module_Path', '/usr/lib/postgresql/14/lib/');
@define('CONST_Max_Word_Frequency', '50000');
@define('CONST_Search_BatchMode', true);
@define('CONST_Import_Node_Cache_Size', '10000000');
@define('CONST_Import_Cache_Flush_Memory', '50');

// Logging settings
@define('CONST_Log_File', '/app/nominatim-project/nominatim.log');
@define('CONST_Log_DB', true);

// Chile-specific settings
@define('CONST_Default_Country', 'cl');
@define('CONST_Default_Language', 'es');
