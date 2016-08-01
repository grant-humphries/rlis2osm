import fiona

from rlis2osm.get_data import define_data_paths

OSM_FIELDS = {
    'access': 'str',
    'bicycle': 'str',
    'bridge': 'str',
    'cycleway': 'str',
    'description': 'str',
    'highway': 'str',
    'layer': 'int',
    'name': 'str',
    'service': 'str',
    'surface': 'str',
    'tunnel': 'str',
    'RLIS:bicycle': 'str'
}

# type --> access
access_map = {
    'private': [1700, 1740, 1750, 1760, 1800, 1850],
    'no': [5402]
}

# type --> service
service_map = {
    'alley': [1600],
    'driveway': [1750, 1850]
}

# type --> surface
surface_map = {
    'unpaved': [2000]
}


def translate_streets():
    streets_shp, trails_shp, bike_routes_shp = define_data_paths()
    bike_tags_map = get_bike_tags(bike_routes_shp)

    with fiona.open(streets_shp) as rlis_streets:
        metadata = rlis_streets.meta.copy()

        with fiona.open(write_streets, 'w', **metadata):
            for feat in rlis_streets:
                tags = feat['properties']
                local_id = tags['LOCALID']
                type_ = tags['TYPE']
                fz_level = tags['fz_level']
                tz_level = tags['tz_level']

                bike_tags = bike_tags_map[local_id]

                osm_tags


def get_bike_tags(bike_routes_path):
    bike_tags = dict()

    with fiona.open(bike_routes_path) as bikes_routes:
        for feat in bikes_routes:
            tags = feat['properties']
            bike_id = tags['BIKEID']
            bike_infra = tags['BIKETYP'] or ''
            bike_there = tags['BIKETHERE']

            bicycle, cycleway, rlis_bicycle = None, None, None

            if not bike_infra and not bike_there:
                continue

            if bike_infra in ('BKE-BLVD', 'BKE-SHRD'):
                cycleway = 'shared_lane'
            elif bike_infra in ('BKE-BUFF', 'BKE-LANE'):
                cycleway = 'lane'
            elif bike_infra == 'BKE-TRAK':
                cycleway = 'track'
            elif bike_infra == 'SHL-WIDE':
                cycleway = 'shoulder'
            # first condition covers 'OTH-CONN', 'OTH-SWLK', 'OTH-XING' values
            elif 'OTH-' in bike_infra or bike_there in ('LT', 'MT', 'HT'):
                bicycle = 'designated'

            if bike_there == 'CA':
                rlis_bicycle = 'caution_area'

            bike_tags[bike_id] = dict(
                bicycle=bicycle,
                cycleway=cycleway,
                rlis_bicycle=rlis_bicycle
            )

    return bike_tags


def get_highway_value(type_, name):
    # highway --> type
    reverse_highway_map = {
        'motorway': [1110, 5101, 5201],
        'motorway_link': [1120, 1121, 1122, 1123],
        'primary': [1200, 1300, 5301],
        'primary_link': [1221, 1222, 1223, 1321],
        'secondary': [1400, 5401, 5451],
        'secondary_link': [1421, 1471],
        'tertiary': [1450, 5402, 5500, 5501],
        'tertiary_link': [1521],
        'residential': [1500, 1550, 1700, 1740, 2000, 8224],
        'service': [1560, 1600, 1750, 1760, 1800, 1850],
        'track': [9000]
    }

    # type --> highway (it's less verbose to store the dictionary as
    # above and then reverse to the form needed for lookups)
    highway_map = {i: k for k, v in reverse_highway_map for i in v}
    highway = highway_map[type_]

    # roads of class residential are named, if the type has indicated
    # residential, but there is no name downgrade to service
    if highway == 'residential' and not name:
        highway = 'service'

    return highway


def get_layer_passage_from_z(fz_level, tz_level):

    layer, bridge, tunnel = None, None, None

    # coalesce layer values to one
    fz_level = fz_level or 1
    tz_level = tz_level or 1
    max_z_level = max(fz_level, tz_level)

    # ground level is 1 for rlis, 0 for osm, rlis skips for 1 to -1 and
    # does not use 0 as a value, in osm a way is assumed to have a layer
    # of 0 unless otherwise indicated
    if fz_level == tz_level:
        if fz_level > 1:
            layer = fz_level - 1
        elif fz_level < 0:
            layer = fz_level
    elif max_z_level > 1:
        layer = max_z_level - 1
    elif max_z_level < 0:
        layer = min(fz_level, tz_level)

    # if layer is not zero assume it is a bridge or tunnel
    if layer > 0:
        bridge = 'yes'
    elif layer < 0:
        tunnel = 'yes'

    return layer, bridge, tunnel


def name_adjustments(highway):
    # motorway_link's have descriptions, not names, via osm convention
    description = None
    if highway == 'motorway_link':
        description = highway
        highway = None

    return highway, description


# this may help in determining how to merge connected segments with
# common attribute with python, replicating what is done with postgis
# below: http://gis.stackexchange.com/questions/61474/
