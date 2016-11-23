import logging as log
import sys
from argparse import ArgumentParser
from collections import OrderedDict
from os.path import join
from subprocess import check_call

import fiona
from fiona.crs import from_epsg
from shapely.geometry import mapping, shape
from titlecase import set_small_word_list, titlecase, SMALL

from rlis2osm import data
from rlis2osm.dissolve import WayDissolver
from rlis2osm.expand import StreetNameExpander
from rlis2osm.translate import generate_bike_mapping, StreetTranslator, \
    TrailsTranslator, OSM_BIKE_FIELDS
from rlis2osm.utils import zip_path, zip_shapefile

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

    street_trans = StreetTranslator()
    trail_trans = TrailsTranslator()
    bike_routes = fiona.open(**zip_path(paths.bikes, encoding=RLIS_ENCODING))
    bike_mapping = generate_bike_mapping(bike_routes)

    s_fields = dict(street_trans.OSM_FIELDS, **OSM_BIKE_FIELDS)
    t_fields = trail_trans.OSM_FIELDS
    combined_fields = OrderedDict(sorted(s_fields.items() + t_fields.items()))
    street_filler = {k: None for k in t_fields if k not in s_fields}
    trail_filler = {k: None for k in s_fields if k not in t_fields}
    bike_filler = {k: None for k in OSM_BIKE_FIELDS}

    streets = fiona.open(**zip_path(paths.streets, encoding=RLIS_ENCODING))
    trails = fiona.open(**zip_path(paths.trails, encoding=RLIS_ENCODING))

    # fiona doesn't recognize rlis's crs string, so it's redefined
    metadata = streets.meta.copy()
    metadata['crs'] = from_epsg(RLIS_EPSG)
    metadata['schema']['properties'] = combined_fields
    metadata['encoding'] = 'utf-8'

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

            # not all streets are in the bike mapping, but a key error
            # is not thrown because a defaultdict is being used
            bike_features = bike_mapping[attrs['LOCALID']]
            bf_count = len(bike_features)
            if bf_count == 0:
                tags.update(bike_filler)
                s['properties'] = tags
                combined.write(s)
            else:
                # if there is more than one bike feature associated with a
                # street the street's geometry needs to be swapped out for
                # the segmented version in the bike data
                for bf in bike_features:
                    if bf_count > 1:
                        bike_fid = bf['fid']
                        s['geometry'] = bike_routes[bike_fid]['geometry']

                    tags.update(bf['tags'])
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
    bike_routes.close()


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
    parser = ArgumentParser(prog='rlis2osm')
    parser.add_argument(
        '-d', '--destination_directory',
        default=None,
        dest='dst_dir',
        help='write location of .osm file'
    )
    parser.add_argument(
        '-r', '--refresh',
        action='store_true',
        help='if flag is supplied the latest rlis data will be downloaded '
             'overwriting any existing files at the same path'
    )
    parser.add_argument(
        '-s', '--source_directory',
        default=None,
        dest='src_dir',
        help='location of source rlis shapefiles if they exist, else write '
             'location for downloaded rlis data'
    )

    log_group = parser.add_mutually_exclusive_group()
    log_group.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='suppress all non-error messages'
    )
    log_group.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='display all messages describing the conversion process'
    )

    options = parser.parse_args(args)
    return options


def main():
    args = sys.argv[1:]
    opts = process_options(args)

    ogr2osm_verbosity = '-q'
    if opts.quiet:
        log_level = log.ERROR
    elif opts.verbose:
        log_level = log.DEBUG
        log.getLogger('Fiona').setLevel(log.INFO)
        ogr2osm_verbosity = '-v'
    else:
        # tone down fiona's logging as it's very verbose and buries
        # this packages logging messages
        log_level = log.INFO
        log.getLogger('Fiona').setLevel(log.ERROR)

    log.basicConfig(
        format='%(levelname)s (%(name)s): %(message)s',
        level=log_level)
    logger = log.getLogger(__name__)
    logger.info('rlis2osm: here we go!')
    logger.info('this conversion should take ten minutes or so...')

    paths = data.main(
        src_dir=opts.src_dir,
        dst_dir=opts.dst_dir,
        refresh=opts.refresh)

    logger.info('expanding abbreviated street names, translating rlis '
                'attributes to osm tags and combining street, trail and bike '
                'information into a single dataset...')
    expand_translate_combine(paths)

    # zip output to keep things tidy
    paths.combined = zip_shapefile(paths.combined, delete_src=True)

    logger.info('merging connected segments that have identical attributes:')
    dissolver = WayDissolver()
    dissolver.dissolve_ways(paths.combined, paths.dissolved)

    logger.info('converting from shapefile to openstreetmap (.osm) format...')
    ogr2osm = join(paths.prj_dir, 'bin', 'ogr2osm')
    translation_file = join(paths.prj_dir, 'rlis2osm', 'repair_keys.py')
    check_call([
        ogr2osm,
        '-f',
        ogr2osm_verbosity,
        '-e', str(RLIS_EPSG),
        '-o', paths.osm,
        '-t', translation_file,
        paths.dissolved
    ])


if __name__ == '__main__':
    main()
