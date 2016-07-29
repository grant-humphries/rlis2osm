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

def translate_streets():
    streets_shp, trails_shp, bike_routes_shp = define_data_paths()

    with fiona.open(streets_shp) as streets:
        for feat in streets:
            tags = feat['properties']
            local_id = tags['LOCALID']
            type_ = tags['TYPE']
            fz_level = tags['fz_level']
            tz_level = tags['tz_level']


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
    hwy_type_map = {
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

    # it's efficient to store the dictionary as above and then reverse
    # to the form needed for lookups
    type_hwy_map = {i: k for k, v in hwy_type_map for i in v}
    highway = type_hwy_map[type_]

    # roads of class residential are named, if the type has indicated
    # residential, but there is no name downgrade to service
    if highway == 'residential' and not name:
        highway = 'service'

    return highway

# service tag
service_type_map = {
    'alley': [1600],
    'driveway': [1750, 1850]
}
# access tag
access_type_map = {
    'private': [1700, 1740, 1750, 1760, 1800, 1850],
    'no': [5402]
}
# surface tag
surface_type_map = {
    'unpaved': [2000]
}


# get osm 'layer' values, ground level 1 in rlis, but 0 for osm
def get_layer_from_z_levels(fz_level, tz_level):

    # coalesce layer values to one
    fz_level = fz_level or 1
    tz_level = tz_level or 1
    max_z_level = max(fz_level, tz_level)

    # not that the value zero is not used in the rlis scheme
    if fz_level == tz_level:
        # if the layer is ground level 'layer' is null
        if fz_level == 1:
            return None
        elif fz_level > 1:
            return fz_level - 1
        elif fz_level < 0:
            return fz_level
    elif max_z_level == 1:
        return None
    elif max_z_level > 1:
        return max_z_level - 1
    elif max_z_level < 0:
        return min(fz_level, tz_level)

# 2) Add bridge and tunnel tags based on the layer value
if layer > 0:
    bridge = 'yes'
elif layer < 0:
    tunnel = 'yes'

# motorway_link's will have descriptions rather than names via osm convention
# source: http://wiki.openstreetmap.org/wiki/Link_%28highway%29
update osm_sts_staging set
    descriptn = array_to_string(array[st_prefix, st_name, st_type, st_direction], ' ')
    where highway = 'motorway_link';


# this may help in determining how to merge connected segments with
# common attribute with python, replicating what is done with postgis
# below: http://gis.stackexchange.com/questions/61474/
