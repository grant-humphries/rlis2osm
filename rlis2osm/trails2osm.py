# rlis trails metadata:
# http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=2404

import fiona

from rlis2osm.get_data import define_data_paths

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


if __name__ == '__main__':
    translate_trails(TRAILS)
