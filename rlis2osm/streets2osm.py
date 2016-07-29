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
}

def translate_streets():
    streets_shp, trails_shp, bike_routes_shp = define_data_paths()

    with fiona.open(streets_shp) as streets:
        for feat in streets:
            tags = feat['properties']
            local_id = tags['LOCALID']
            type_ = tags['TYPE']
            fz_level = tags['F_ZLEV']
            tz_level = tags['T_ZLEV']


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
def get_layer_from_zlev(f_zlev, t_zlev):

    # coalesce layer values to one
    f_zlev = f_zlev or 1
    t_zlev = t_zlev or 1
    max_zlev = max(f_zlev, t_zlev)

    # not that the value zero is not used in the rlis scheme
    if f_zlev == t_zlev:
        # if the layer is ground level 'layer' is null
        if f_zlev == 1:
            return None
        elif f_zlev > 1:
            return f_zlev - 1
        elif f_zlev < 0:
            return f_zlev
    elif max_zlev == 1:
        return None
    elif max_zlev > 1:
        return max_zlev - 1
    elif max_zlev < 0:
        return min(f_zlev, t_zlev)




# 2) Add bridge and tunnel tags based on the layer value
if layer > 0:
    bridge = 'yes'
elif layer < 0:
    tunnel = 'yes'



# 3) Expand abbreviations that are within the street basename
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Av[e]?(-|\s|$)', '\1Avenue\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Blvd(-|\s|$)', '\1Boulevard\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Br[g]?(-|\s|$)', '\1Bridge\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Ct(-|\s|$)', '\1Court\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Dr(-|\s|$)', '\1Drive\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Fwy(-|\s|$)', '\1Freeway\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Pkwy(-|\s|$)', '\1Parkway\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Pl(-|\s|$)', '\1Place\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Rd(-|\s|$)', '\1Road\2 ', 'gi');
# St > Street (will not occur at beginning of a st_name)
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)St(-|\s|$)', '\1Street\2 ', 'gi');

# Expand other abbreviated parts of street basename
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Cc(-|\s|$)', '\1Community College\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Co(-|\s|$)', '\1County\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Jr(-|\s|$)', '\1Junior\2', 'gi');
# Mt at beginning of name is 'Mount' later in name is 'Mountain'
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|-|-\s)Mt(\s)', '\1Mount\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Mt(-|\s|$)', '\1Mountain\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Nfd(-|\s|$)', '\1National Forest Development Road\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Tc(-|\s|$)', '\1Transit Center\2', 'gi');
# St > Saint (will only occur at the beginning of a street name)
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|-|-\s)(Mt\s|Mount\s|Old\s)?St[\.]?(\s)', '\1\2Saint\3', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Us(-|\s|$)', '\1United States\2', 'gi');

# special case grammar fixes and name expansions
update osm_sts_staging set st_name =
    # the '~' operator does a posix regular expression comparison between strings
    case when st_name ~ '.*(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$).*'
    then format_titlecase(regexp_replace(st_name,
        '(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3', 'gi'))
    else st_name end;

update osm_sts_staging set st_name =
    case when st_name ~ '.*(^|\s|-)Ft\sOf\s.*' then
        case when st_name ~ '.*(^|\s|-)Holladay(-|\s|$).*'
            then regexp_replace(st_name, 'Ft\sOf\sN', 'Foot of North', 'gi')
        when st_name ~ '.*(^|\s|-)(Madison|Marion)(-|\s|$).*'
            then regexp_replace(st_name, 'Ft\sOf\sSe', 'Foot of Southeast', 'gi')
        else st_name end
    else st_name end;

# more special case name expansions
# for these an index is created and matches are made on the full name of the
# field to decrease run time of script
update osm_sts_staging set st_name = 'Bonneville Power Administration'
    where st_name = 'Bpa';
update osm_sts_staging set st_name = 'John Quincy Adams'
    where st_name = 'Jq Adams';
update osm_sts_staging set st_name = 'Sunnyside Hospital-Mount Scott Medical Transit Center'
    where st_name = 'Sunnyside Hosp-Mount Scott Med Transit Center';


# 4) Now that abbreviations in street names have been expanded concatenate their parts
# concat strategy via http://www.laudatio.com/wordpress/2009/04/01/a-better-concat-for-postgresql/
update osm_sts_staging set
    name = array_to_string(array[st_prefix, st_name, st_type, st_direction], ' ')
    where highway != 'motorway_link'
        or highway is null;

# motorway_link's will have descriptions rather than names via osm convention
# source: http://wiki.openstreetmap.org/wiki/Link_%28highway%29
update osm_sts_staging set
    descriptn = array_to_string(array[st_prefix, st_name, st_type, st_direction], ' ')
    where highway = 'motorway_link';


# this may help in determining how to merge connected segments with
# common attribute with python, replicating what is done with postgis
# below: http://gis.stackexchange.com/questions/61474/
