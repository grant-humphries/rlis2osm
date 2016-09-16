import os
import sys
from argparse import ArgumentParser
from collections import OrderedDict
from os.path import exists

import fiona
from shapely.geometry import mapping, shape
from titlecase import set_small_word_list, titlecase, SMALL

from rlis2osm import data
from rlis2osm.dissolve import WayDissolver
from rlis2osm.expand import StreetNameExpander
from rlis2osm.translate import get_bike_tag_map, StreetTranslator, \
    TrailsTranslator
from rlis2osm.utils import zip_path

RLIS_ENCODING = 'cp1252'
RLIS_EPSG = 2913
RLIS_SPECIAL = [
    # names
    ('AM', 'Archibald M', 'fm'),  # 'AM Kennedy'
    ('HM', 'Howard M', 'fm'),  # 'HM Terpenning'
    ('JQ', 'John Quincy', 'fm'),
    ('UJ', 'Ulin J', 'fm'),

    # regional
    ('BES', 'Bureau of Environmental Services', 'a'),
    ('BPA', 'Bonneville Power Administration', 'a'),
    ('MAX', 'Metropolitan Area Express', 'a'),
    ('NCPRD', 'North Clackamas Parks & Recreation District', 'a'),
    ('PCC', 'Portland Community College', 'a'),
    ('PKW', 'Peterkort Woods', 'fm'),
    ('PSU', 'Portland State University', 'a'),
    ('THPRD', 'Tualatin Hills Park & Recreation District', 'a'),
    ('TVWD', 'Tualatin Valley Water District', 'a'),
    ('WES', 'Westside Express Service', 'a'),
    ('WSU', 'Washington State University', 'a'),

    # rlis specific
    ('CO', 'County', 'f')
]


def expand_translate_combine(paths):
    expander = StreetNameExpander(special_cases=RLIS_SPECIAL)
    tc_callback = customize_titlecase()

    bike_routes = fiona.open(**zip_path(paths.bikes, encoding=RLIS_ENCODING))
    bike_mapping = get_bike_tag_map(bike_routes)
    street_trans = StreetTranslator(bike_mapping)
    trail_trans = TrailsTranslator()

    s_fields = street_trans.OSM_FIELDS
    t_fields = trail_trans.OSM_FIELDS
    combined_fields = OrderedDict(sorted(s_fields.items() + t_fields.items()))
    street_filler = {k: None for k in t_fields if k not in s_fields}
    trail_filler = {k: None for k in s_fields if k not in t_fields}

    streets = fiona.open(**zip_path(paths.streets, encoding=RLIS_ENCODING))
    trails = fiona.open(**zip_path(paths.trails, encoding=RLIS_ENCODING))

    metadata = streets.meta.copy()
    metadata['schema']['properties'] = combined_fields
    metadata['encoding'] = 'utf-8'

    # fiona can't overwrite geojson like it can shapefiles
    if exists(paths.combined):
        os.remove(paths.combined)

    # note that the field names that have colons or exceed 10 characters
    # will be modified due to .dbf spec, they are reinstated during the
    # ogr2osm step, I attempted to switch to geojson to get around this,
    # but reading geojson from disk is much slower than shapefile
    with fiona.open(paths.combined, 'w', **metadata) as combined:
        for s in streets:
            attrs = s['properties']

            # expand abbreviations in all street name parts
            attrs['PREFIX'] = expander.direction(attrs['PREFIX'])
            attrs['STREETNAME'] = expander.basename(attrs['STREETNAME'])
            attrs['FTYPE'] = expander.type(attrs['FTYPE'])
            attrs['DIRECTION'] = expander.direction(attrs['DIRECTION'])

            # street names in rlis are in all caps and thus need to be
            # title-cased, the titlecase package has special handling
            # for all caps text and thus needs to be lower cased
            tags = street_trans.translate(attrs)
            name_tag = (tags['name'] or '').lower()
            tags['name'] = titlecase(name_tag, callback=tc_callback)

            tags.update(street_filler)
            s['properties'] = tags

            combined.write(s)

        for t in trails:
            attrs = t['properties']

            # expand abbreviations for and title case all name fields,
            # encoding is explicitly set due to Windows issues
            for name in ('AGENCY', 'SHARED', 'SYSTEM', 'TRAIL'):
                name_key = '{}NAME'.format(name)
                attrs[name_key] = expander.basename(attrs[name_key])

            tags = trail_trans.translate(attrs)
            if 'drop' in tags:
                continue

            tags.update(trail_filler)
            t['properties'] = tags

            # break multipart geometries into separate features
            geom = shape(t['geometry'])
            if 'multi' in geom.type.lower():
                for part in geom:
                    t['geometry'] = mapping(part)
                    combined.write(t)
            else:
                combined.write(t)

    streets.close()
    trails.close()

    # TODO: zip up output to keep things tidy


def customize_titlecase():

    # don't lowercase 'v', do lowercase 'with'
    small = SMALL.replace('|v\.?|', '|')
    small = '{}|with'.format(small)
    set_small_word_list(small)

    def number_after_letter(word, **kwargs):
        # even though the kwargs aren't used here they are a requirement of
        # any function supplied to titlecase as a callback

        if word and word[0].isdigit() and word[-1].isalpha():
            # cases like '45th'
            if word[-2].isalpha():
                word.lower()
            # cases like '99W'
            else:
                word.upper()

            return word
        else:
            return None

    return number_after_letter


def process_options(args):
    parser = ArgumentParser()
    parser.add_argument(
        '-d', '--destination_directory',
        default=None,
        dest='dst_dir',
        help='write location finished product'
    )
    parser.add_argument(
        '-r', '--refresh_data',
        default=False,
        dest='refresh',
        type=bool,
        help='if set to true existing rlis data will be overwritten with the '
             "latest version from the Metro's website"
    )
    parser.add_argument(
        '-s', '--source_directory',
        default=None,
        dest='src_dir',
        help='location of source rlis shapefiles if they exist, else write '
             'location for downloaded datasets'
    )

    options = parser.parse_args(args)
    return options


def main():
    args = sys.argv[1:]
    opts = process_options(args)

    paths = data.main(
        src_dir=opts.src_dir,
        dst_dir=opts.dst_dir,
        refresh=opts.refresh)

    # expand_translate_combine(paths)
    dissolver = WayDissolver()
    dissolver.dissolve_ways(paths.combined, paths.dissolved)

    # module execution order: data, expand, translate, combine, dissolve, ogr2osm

if __name__ == '__main__':
    main()
