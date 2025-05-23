# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of Nominatim. (https://nominatim.org)
#
# Copyright (C) 2025 by the Nominatim developer community.
# For a full list of authors see the git log.
"""
Tests for freeze functions (removing unused database parts).
"""
from nominatim_db.tools import freeze

NOMINATIM_RUNTIME_TABLES = [
    'country_name', 'country_osm_grid',
    'location_postcode', 'location_property_osmline', 'location_property_tiger',
    'placex', 'place_adressline',
    'search_name',
    'word'
]

NOMINATIM_DROP_TABLES = [
    'address_levels',
    'location_area', 'location_area_country', 'location_area_large_100',
    'location_road_1',
    'place', 'planet_osm_nodes', 'planet_osm_rels', 'planet_osm_ways',
    'search_name_111',
    'wikipedia_article', 'wikipedia_redirect'
]


def test_drop_tables(temp_db_conn, temp_db_cursor, table_factory):
    for table in NOMINATIM_RUNTIME_TABLES + NOMINATIM_DROP_TABLES:
        table_factory(table)

    assert not freeze.is_frozen(temp_db_conn)

    freeze.drop_update_tables(temp_db_conn)

    for table in NOMINATIM_RUNTIME_TABLES:
        assert temp_db_cursor.table_exists(table)

    for table in NOMINATIM_DROP_TABLES:
        assert not temp_db_cursor.table_exists(table)

    assert freeze.is_frozen(temp_db_conn)


def test_drop_flatnode_file_no_file():
    freeze.drop_flatnode_file(None)


def test_drop_flatnode_file_file_already_gone(tmp_path):
    freeze.drop_flatnode_file(tmp_path / 'something.store')


def test_drop_flatnode_file_delete(tmp_path):
    flatfile = tmp_path / 'flatnode.store'
    flatfile.write_text('Some content')

    freeze.drop_flatnode_file(flatfile)

    assert not flatfile.exists()
