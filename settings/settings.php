<?php
// Database connection settings
@define('CONST_Database_DSN', 'pgsql:host=localhost;port=5432;dbname=nominatim;user=nominatim;password=nominatim');

// Website settings
@define('CONST_Website_BaseURL', '/');

// Paths
@define('CONST_Osm2pgsql_Binary', '/usr/local/bin/osm2pgsql');
@define('CONST_Osmium_Binary', '/usr/bin/osmium');
@define('CONST_Tiger_Data_Path', '');

// Import settings
@define('CONST_Import_Style', 'full');
@define('CONST_Import_Node_Cache_Size', '2500');
@define('CONST_Import_Cache_Flush_Memory', '50');

// Update settings
@define('CONST_Replication_Url', 'https://download.geofabrik.de/south-america/chile-updates/');
@define('CONST_Replication_MaxInterval', '86400');     // Process each day
@define('CONST_Replication_Update_Interval', '86400'); // How often upstream publishes diffs
@define('CONST_Replication_Recheck_Interval', '900');  // How long to sleep if no update found

// Logging settings
@define('CONST_Log_DB', true);
@define('CONST_Log_File', '/app/nominatim-project/nominatim.log');

// Search settings
@define('CONST_Search_BatchMode', true);
@define('CONST_Max_Word_Frequency', '50000');