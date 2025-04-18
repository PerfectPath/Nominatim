<?php
@define('CONST_Database_DSN', 'pgsql:host=localhost;port=5432;dbname=nominatim;user=nominatim;password=nominatim');
@define('CONST_Website_BaseURL', '/');
@define('CONST_Osm2pgsql_Binary', '/usr/bin/osm2pgsql');
@define('CONST_Database_Module_Path', '/usr/lib/postgresql/12/lib/');
@define('CONST_Postgresql_Version', '12');
@define('CONST_Postgis_Version', '3');
@define('CONST_Import_Style', 'full');
@define('CONST_Database_Web_User', 'www-data');
@define('CONST_Database_Web_Password', 'nominatim');
@define('CONST_Import_Style_Local', CONST_Import_Style);
@define('CONST_Log_DB', true);
@define('CONST_Log_File', '/app/nominatim-project/nominatim.log');