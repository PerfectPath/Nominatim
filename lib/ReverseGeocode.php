<?php

namespace Nominatim;

require_once(CONST_BasePath.'/lib/Result.php');

class ReverseGeocode
{
    protected $oDB;
    protected $iMaxRank = 28;


    public function __construct(&$oDB)
    {
        $this->oDB =& $oDB;
    }


    public function setZoom($iZoom)
    {
        // Zoom to rank, this could probably be calculated but a lookup gives fine control
        $aZoomRank = array(
                      0 => 2, // Continent / Sea
                      1 => 2,
                      2 => 2,
                      3 => 4, // Country
                      4 => 4,
                      5 => 8, // State
                      6 => 10, // Region
                      7 => 10,
                      8 => 12, // County
                      9 => 12,
                      10 => 17, // City
                      11 => 17,
                      12 => 18, // Town / Village
                      13 => 18,
                      14 => 22, // Suburb
                      15 => 22,
                      16 => 26, // Street, TODO: major street?
                      17 => 26,
                      18 => 30, // or >, Building
                      19 => 30, // or >, Building
                     );
        $this->iMaxRank = (isset($iZoom) && isset($aZoomRank[$iZoom]))?$aZoomRank[$iZoom]:28;
    }

    /**
     * Find the closest interpolation with the given search diameter.
     *
     * @param string $sPointSQL   Reverse geocoding point as SQL
     * @param float  $fSearchDiam Search diameter
     *
     * @return Record of the interpolation or null.
     */
    protected function lookupInterpolation($sPointSQL, $fSearchDiam)
    {
        $sSQL = 'SELECT place_id, parent_place_id, 30 as rank_search,';
        $sSQL .= '  ST_LineLocatePoint(linegeo,'.$sPointSQL.') as fraction,';
        $sSQL .= '  startnumber, endnumber, interpolationtype,';
        $sSQL .= '  ST_Distance(linegeo,'.$sPointSQL.') as distance';
        $sSQL .= ' FROM location_property_osmline';
        $sSQL .= ' WHERE ST_DWithin('.$sPointSQL.', linegeo, '.$fSearchDiam.')';
        $sSQL .= ' and indexed_status = 0 and startnumber is not NULL ';
        $sSQL .= ' ORDER BY distance ASC limit 1';

        return chksql(
            $this->oDB->getRow($sSQL),
            'Could not determine closest housenumber on an osm interpolation line.'
        );
    }
    
    protected function lookupPolygon($sPointSQL, $iMaxRank)
    {
        $sSQL = 'select place_id,parent_place_id,rank_search,country_code, geometry';
        $sSQL .= ' FROM placex';
        $sSQL .= ' WHERE ST_GeometryType(geometry) in (\'ST_Polygon\',\'ST_MultiPolygon\')';
        $sSQL .= ' AND rank_search <= LEAST(25, '.$iMaxRank.')';
        $sSQL .= ' AND ST_CONTAINS(geometry, '.$sPointSQL.' )';
        $sSQL .= ' AND type != \'postcode\' ';
        $sSQL .= ' AND name IS NOT NULL ';
        $sSQL .= ' ORDER BY rank_search DESC LIMIT 1';

        $aPoly = chksql(
            $this->oDB->getRow($sSQL),
            'Could not determine polygon containing the point.'
        );
        if ($aPoly) {
            $iParentPlaceID = $aPoly['parent_place_id'];
            $iRankSearch = $aPoly['rank_search'];
            $iGeometry = $aPoly['geometry'];
            
            $sSQL = 'select place_id,parent_place_id,rank_search,country_code,';
            $sSQL .='  ST_distance('.$sPointSQL.', geometry) as distance';
            $sSQL .= ' FROM placex';
            $sSQL .= ' WHERE osm_type = \'N\'';
            $sSQL .= ' AND rank_search >= '.$iRankSearch;
            $sSQL .= ' AND rank_search <= LEAST(25, '.$iMaxRank.')';
            $sSQL .= ' AND ST_CONTAINS(\''.$iGeometry.'\'::geometry, geometry )';
            $sSQL .= ' AND type != \'postcode\'';
            $sSQL .= ' AND name IS NOT NULL ';
            $sSQL .= ' ORDER BY distance ASC,';
            $sSQL .= ' rank_search DESC';
            $sSQL .= ' limit 1';
            if (CONST_Debug) var_dump($sSQL);
            $aPlacNode = chksql(
                $this->oDB->getRow($sSQL),
                'Could not determine place node.'
            );
            if ($aPlacNode) {
                return $aPlacNode;
            }
        }
        return $aPoly;
    }

    public function lookup($fLat, $fLon, $bDoInterpolation = true)
    {
        return $this->lookupPoint(
            'ST_SetSRID(ST_Point('.$fLon.','.$fLat.'),4326)',
            $bDoInterpolation
        );
    }

    public function lookupPoint($sPointSQL, $bDoInterpolation = true)
    {
        
        $iMaxRank = $this->iMaxRank;

        // Find the nearest point
        $fSearchDiam = 0.006;
        $oResult = null;
        $aPlace = null;
        $fMaxAreaDistance = 1;
        $bIsTigerStreet = false;
        
        // for POI or street level
        if ( $iMaxRank >= 26 ) {
            
            $sSQL = 'select place_id,parent_place_id,rank_search,country_code,';
            $sSQL .= 'CASE WHEN ST_GeometryType(geometry) in (\'ST_Polygon\',\'ST_MultiPolygon\') THEN ST_distance('.$sPointSQL.', centroid)';
            $sSQL .= ' ELSE ST_distance('.$sPointSQL.', geometry) ';
            $sSQL .= ' END as distance';
            $sSQL .= ' FROM ';
            $sSQL .= ' placex';
            $sSQL .= '   WHERE ST_DWithin('.$sPointSQL.', geometry, '.$fSearchDiam.')';
            $sSQL .= '   AND';
            // only streets
            if ($iMaxRank == 26) {
                $sSQL .= ' rank_search != 28 and rank_search = 26';
            } else {
                $sSQL .= ' rank_search != 28 and rank_search >= 26';
            }
            $sSQL .= ' and (name is not null or housenumber is not null';
            $sSQL .= '      or rank_search between 26 and 27)';
            $sSQL .= ' and type not in (\'proposed\')';
            $sSQL .= ' and class not in (\'waterway\',\'railway\',\'tunnel\',\'bridge\',\'man_made\')';
            $sSQL .= ' and indexed_status = 0 and linked_place_id is null';
            $sSQL .= ' and (ST_GeometryType(geometry) not in (\'ST_Polygon\',\'ST_MultiPolygon\') ';
            $sSQL .= ' OR ST_DWithin('.$sPointSQL.', centroid, '.$fSearchDiam.'))';
            $sSQL .= ' ORDER BY distance ASC limit 1';
            if (CONST_Debug) var_dump($sSQL);
            $aPlace = chksql(
                $this->oDB->getRow($sSQL),
                'Could not determine closest place.'
            );
            
            if ($aPlace) {
                    $iPlaceID = $aPlace['place_id'];
                    $oResult = new Result($iPlaceID);
                    $iParentPlaceID = $aPlace['parent_place_id'];
                    // if street and maxrank > streetlevel
                    if (($aPlace['rank_search'] == 26 || $aPlace['rank_search'] == 27)&& $iMaxRank > 27 ) {
                        // find the closest object (up to a certain radius) of which the street is a parent of
                        $sSQL = ' select place_id,parent_place_id,rank_search,country_code,';
                        $sSQL .= ' ST_distance('.$sPointSQL.', geometry) as distance';
                        $sSQL .= ' FROM ';
                        $sSQL .= ' placex';
                        // radius ?
                        $sSQL .= ' WHERE ST_DWithin('.$sPointSQL.', geometry, 0.003)';
                        $sSQL .= ' AND parent_place_id = '.$iPlaceID;
                        $sSQL .= ' and (name is not null or housenumber is not null)';
                        $sSQL .= ' ORDER BY distance ASC limit 1';
                        if (CONST_Debug) var_dump($sSQL);
                        $aStreet = chksql(
                            $this->oDB->getRow($sSQL),
                            'Could not determine closest place.'
                        );
                        if ($aStreet) {
                            $iPlaceID = $aStreet['place_id'];
                            $oResult = new Result($iPlaceID);
                            $iParentPlaceID = $aStreet['parent_place_id'];
                        }
                    } 
                }else{
                    $aPlace = $this->lookupPolygon($sPointSQL, $iMaxRank);
                    if ($aPlace) {
                        $oResult = new Result($aPlace['place_id']);
                    }
                }
            // lower than street level ($iMaxRank < 26 )
            }else{
                $aPlace = $this->lookupPolygon($sPointSQL, $iMaxRank);
                if ($aPlace) {
                    $oResult = new Result($aPlace['place_id']);
            }
            
        }  
        return $oResult;
    }

}