import fiona

from rlis2osm.data import define_data_paths
from rlis2osm.dissolve import OgrReader



class StreetTranslator(OgrReader):
    osm_fields = {
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


    def translate_streets(self, bike_tags_map):
        metadata = self.features.meta.copy()

        with fiona.open(write_streets, 'w', **metadata):
            for feat in self.features:
                tags = feat['properties']
                local_id = tags['LOCALID']
                name = tags['name']
                type_ = tags['TYPE']
                fz_level = tags['fz_level']
                tz_level = tags['tz_level']


                bike_tags = bike_tags_map[local_id]

                highway = self._get_highway_value(type_, name)

    def _get_highway_value(self, type_, name):
        # highway --> type


        # type --> highway (it's less verbose to store the dictionary as
        # above and then reverse to the form needed for lookups)
        highway_map = {i: k for k, v in reverse_highway_map for i in v}
        highway = highway_map[type_]

        # roads of class residential are named, if the type has indicated
        # residential, but there is no name downgrade to service
        if highway == 'residential' and not name:
            highway = 'service'

        return highway

    def _get_layer_passage_from_z(self, fz_level, tz_level):

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


    def _name_adjustments(self, highway):
        # motorway_link's have descriptions, not names, via osm convention
        description = None
        if highway == 'motorway_link':
            description = highway
            highway = None

        return highway, description


# this may help in determining how to merge connected segments with
# common attribute with python, replicating what is done with postgis
# below: http://gis.stackexchange.com/questions/61474/


class BikeTranslator(OgrReader):

    def get_bike_tags(self):
        bike_tags = dict()

        for feat in self.features:
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










# rlis trails metadata:
# http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=2404

# import fiona
#
# from rlis2osm.get_data import define_data_paths

TRAILS = '/some/path/to/some/trails'

# TODO rethink how mountain bike info is handled given that mtb is not a valid key
osm_fields = {
    'abandoned:highway': 'str',
    'access': 'str',
    'alt_name': 'str',
    'bicycle': 'str',
    'construction': 'str',
    'est_width': 'float',
    'fee': 'str',
    'foot': 'str',
    'highway': 'str',
    'horse': 'str',
    'name': 'str',
    'operator': 'str',
    'proposed': 'str',
    'surface': 'str',
    'wheelchair': 'str',
    'RLIS:system_name': 'str'
}

# mappings for simple conversions
access_map = {
    'Restricted_Private': 'private',
    'Unknown': 'unknown'
}

# status --> fee
fee_map = {
    'Open_Fee': 'yes'
}

# trl_surface --> surface ('Stairs' and 'Water' are also valid values,
# but don't map to osm's surface)
surface_map = {
    'Chunk Wood': 'woodchips',
    'Decking': 'wood',
    'Hard Surface': 'paved',
    'Imported Material': 'compacted',
    'Native Material': 'ground',
    'Snow': 'snow',
    'Unknown': None
}

# accessible --> wheelchair
wheelchair_map = {
    'Accessible': 'yes',
    'Not Accessible': 'no'
}


def translate_trails(trails_path):
    with fiona.open(trails_path) as rlis_trails:
        metadata = rlis_trails.meta.copy()

        # switch output to geojson to support field name larger than 10
        # characters
        metadata['driver'] = ['GeoJSON']
        metadata['schema']['properties'] = osm_fields

        with fiona.open(write_path, 'w', **metadata) as osm_trails:
            for feat in rlis_trails:
                tags = feat['properties']
                accessible = tags['ACCESSIBLE']
                agency_name = tags['AGENCYNAME']
                equestrian = tags['EQUESTRIAN']
                hike = tags['HIKE']
                mtn_bike = tags['MTNBIKE']
                on_str_bike = tags['ONSTRBIKE']
                road_bike = tags['ROADBIKE']
                shared_name = tags['SHAREDNAME']
                status = tags['STATUS']
                system_name = tags['SYSTEMNAME']
                trail_name = tags['TRAILNAME']
                trl_surface = tags['TRLSUFACE']
                width = tags['WIDTH']

                # remove segments meeting these criteria, on street bike
                # segments exists in the streets data so aren't needed here
                if on_str_bike == 'Yes' or status == 'Conceptual' or \
                        trl_surface == 'Water':
                    continue

                agency_name, shared_name, system_name =

                # these osm tags are needed as part of the computation of
                # other tags
                est_width = get_est_width(width, 0.25)
                highway, modes = get_mode_tags(
                    est_width, equestrian, hike, mtn_bike, on_str_bike, road_bike)

                osm_tags = dict(
                    # TODO need colon in this tag, so not sure if I can instantiate the dict this way
                    abandoned_highway=None,
                    access=access_map.get(status),
                    alt_name=shared_name,
                    bicyle=modes['bicycle'],
                    construction=None,
                    est_width=est_width,
                    fee=fee_map.get(status),
                    foot=modes['foot'],
                    highway=highway,
                    horse=modes['horse'],
                    name=trail_name,
                    operator=agency_name,
                    proposed=None,
                    surface=surface_map.get(trl_surface),
                    wheelchair=wheelchair_map.get(accessible),
                    rlis_systemname=system_name
                )

                # for certain status values the highway value should be
                # moved to others keys
                if status == 'Decommissioned':
                    osm_tags['abandoned:highway'] = osm_tags['highway']
                    osm_tags['highway'] = None
                elif status == 'Planned':
                    osm_tags['proposed'] = osm_tags['highway']
                    osm_tags['highway'] = 'proposed'
                elif status == 'Under construction':
                    osm_tags['construction'] = osm_tags['highway']
                    osm_tags['highway'] = 'construction'

                feat['properties'] = osm_tags
                osm_trails.write(feat)


def get_est_width(rlis_width, round_res):
    est_width = None
    plus_bonus = 1.25

    # most rlis widths are in ranges, e.g. 6-9
    if '-' in rlis_width:
        min_, max_ = rlis_width.split('-')
        est_width = (float(min_)+float(max_)) / 2
    # some specify that they're at least a certain with, e.g. 15+
    elif '+' in rlis_width:
        est_width = float(rlis_width.replace('+', '')) * plus_bonus
    elif rlis_width == 'Unknown':
        est_width = None

    # convert to meters and round to supplied unit
    if est_width:
        est_width = round(est_width * 0.3048, round_res) * round_res

    return est_width


def get_mode_tags(
        equestrian, est_width, hike, mtn_bike, road_bike, trl_surface):
    """determine value for highway and mode access tags base on mode
    permissions and trail width
    """

    bicycle, foot, horse = None, None, None
    path_conditions = [
        equestrian == 'Yes',
        hike == 'Yes',
        mtn_bike == 'Yes',
        road_bike == 'Yes' and est_width > 3
    ]

    if trl_surface == 'Stairs':
        highway = 'steps'
    elif n_any(path_conditions, 2):
        highway = 'path'

        if equestrian == 'Yes':
            horse = 'designated'
        elif equestrian == 'No':
            horse = 'no'

        if hike:
            foot = 'designated'

        if road_bike or mtn_bike:
            bicycle = 'designated'
    elif road_bike == 'Yes':
        highway = 'cycleway'
    elif equestrian == 'Yes':
        highway = 'bridleway'
    else:
        highway = 'footway'

        if road_bike:
            bicycle = 'yes'

    if hike == 'No':
        foot = 'no'

    if (mtn_bike == 'No' and road_bike != 'Yes') or \
            (road_bike == 'No' and mtn_bike != 'Yes'):
        bicycle = 'no'

    return highway, dict(bicycle=bicycle, foot=foot, horse=horse)


def n_any(iterable, n):
    trues = 0
    for element in iterable:
        if element:
            trues += 1
            if trues >= n:
                return True

    return False


def name_adjustments(agency_name, shared_name, system_name, trail_name):
    # name adjustments, no duplicate names
    if shared_name == trail_name:
        shared_name = None

    if system_name in (trail_name, shared_name):
        system_name = None

    if agency_name == 'Unknown':
        agency_name = None

    return agency_name, shared_name, system_name

def highway_special_cases():
    pass

def main():
    streets_path, trails_path, bikes_path = define_data_paths()
    streets_trans = StreetTranslator(streets_path)
    bike_trans = BikeTranslator(bikes_path)

if __name__ == '__main__':
    translate_trails(TRAILS)
