import sys
from argparse import ArgumentParser

import fiona
from titlecase import set_small_word_list, titlecase, SMALL

from rlis2osm.data import RlisPaths
from rlis2osm.expand import StreetNameExpander
from rlis2osm.translate import get_bike_tag_map, StreetTranslator, \
    TrailsTranslator

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
    ('PCC', 'Portland Community College', 'a'),
    ('PKW', 'Peterkort Woods', 'fm'),
    ('PSU', 'Portland State University', 'a'),
    ('THPRD', 'Tualatin Hills Park & Recreation District', 'a'),
    ('TVWD', 'Tualatin Valley Water District', 'a'),
    ('WES', 'Westside Express Service', 'a'),
    ('WSU', 'Washington State University' 'a'),

    # rlis specific
    ('CO', 'County', 'f')
]


def rlis2osm(paths):
    expander = StreetNameExpander(special_cases=RLIS_SPECIAL)
    bike_routes = fiona.open(paths.bikes)
    bike_mapping = get_bike_tag_map(bike_routes)
    street_trans = StreetTranslator(bike_mapping)
    trail_trans = TrailsTranslator()

    streets = fiona.open(paths.streets)
    trails = fiona.open(paths.trails)

    # get projection info, feat type, etc from streets then modify schema
    metadata = streets.meta.copy()
    metadata['schema']['properties'] =

    # TODO get epsg from schema to feed to ogr2osm

    with fiona.open(paths.combined, 'w', **metadata) as combined:
        for s in streets:
            attrs = s['properties']

            # expand abbreviations in all street name parts
            attrs['PREFIX'] = expander.direction(attrs['PREFIX'])
            attrs['STREETNAME'] = expander.basename(attrs['STREETNAME'])
            attrs['FTYPE'] = expander.type(attrs['FTYPE'])
            attrs['DIRECTION'] = expander.direction(attrs['DIRECTION'])

            # convert attributes to osm and title case names
            tags = street_trans.translate_streets(attrs)
            tags['name'] = titlecase(tags['name'], callback=tc_callback)
            s['properties'] = tags

            combined.write(s)

        for t in trails:
            attrs = t['properties']

            # expand abbreviations for and title case all name fields
            for name in ('AGENCY', 'SHARED', 'SYSTEM', 'TRAIL'):
                name_key = '{}NAME'.format(name)
                exp_name = expander.basename(attrs[name_key])
                attrs[name_key] = titlecase(exp_name, callback=tc_callback)

            t['properties'] = trail_trans.translate_trails(attrs)

            combined.write(t)



def process_options():
    parser = ArgumentParser()
    parser.add_argument(
        '-d', '--destination_path'
    )
    parser.add_argument(
        '-r', '--refresh_data',
    )

    parser.add_argument(
        '-s', '--source_path',
        help='file path at which datasets will be downloaded and written to'
    )


def customize_titlecase():

    # don't lowercase 'v', do lowercase 'with'
    small = SMALL.replace('|v\.?|', '|')
    small = '{}|with'.format(small)
    set_small_word_list(small)

    def number_after_letter(word, **kwargs):
        # even though the kwargs aren't used here they are a requirement of
        # any function supplied to titlecase as a callback

        if word[0].isdigit() and word[-1].isalpha():
            # cases like '45th'
            if word[-2].isalpha():
                word.lower()
            # cases like '99W'
            else:
                word.upper()

        return word

    return number_after_letter


def main():

    opts = process_options()
    paths = RlisPaths()

    # module execution order: data, expand, translate, combine, dissolve, ogr2osm

if __name__ == '__main__':
    main()