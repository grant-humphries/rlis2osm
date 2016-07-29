# rlis trails metadata:
# http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=2404

import fiona

TRAILS = '/some/path/to/some/trails'

# TODO rethink how mountain bike info is handle give that mtb is not a valid tag
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

# dictionaries for simple conversions:
# status --> access
access_map = {
    'Restricted_Private': 'private',
    'Unknown': 'unknown'
}

# equestrian, hike --> horse, foot (respectively)
mode_access_map = {
    'No': 'no',
    'Yes': 'designated'
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
    with fiona.open(trails_path) as trails:
        for feat in trails:
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

            # these osm tags are needed as part of the computation of
            # other tags
            osm_width = get_est_width(width, 0.25)
            highway = get_highway_value(
                equestrian, hike, mtn_bike, on_str_bike, osm_width,
                road_bike, trl_surface)

            osm_tags = dict(
                # TODO need colon in this tag, so not sure if I can instantiate the dict this way
                abandoned_highway=None,
                access=access_map.get(status),
                bicyle=get_bicycle_permissions(
                    on_str_bike, osm_width, road_bike, trl_surface),
                construction=None,
                est_width=osm_width,
                fee=fee_map.get(status),
                foot=mode_access_map.get(hike),
                highway=get_highway_value(
                    equestrian, hike, mtn_bike, on_str_bike, osm_width, 
                    road_bike, trl_surface),
                horse=mode_access_map.get(equestrian),
                name=trail_name,
                operator=agency_name,
                proposed=None,
                surface=surface_map.get(trl_surface),
                wheelchair=wheelchair_map.get(accessible),
                rlis_systemname=system_name
            )

            # clean-up issues that couldn't be handled from initial mappings

            # 'abandoned:highway' - decommissioned trails have their 'highway' values
            # moved here
            if status == 'Decommissioned':
                abndnd_hwy = highway
                highway = None
            elif status == 'Under construction':
                construction = highway
                highway = 'construction'
            elif status == 'Planned':
                proposed = highway
                highway = 'proposed'

            # 'operator' - managing agency
            if agency_name == 'Unknown':
                agency_name = None

            # 'RLIS:system_name' - rlis system name, these may eventually be used to create
            # relations, but for now don't include this attribute if it is identical one of
            # the trails other names
            if system_name == trail_name or system_name == shared_name:
                system_name = None

            # highway type 'footway' implies foot permissions, it's redundant to have this
            # information in the 'foot' tag as well, same goes for 'cycleway' and 'bridleway'
            if highway == 'footway':
                foot = None
            elif highway == 'cycleway':
                bicycle = None
            elif highway == 'bridleway':
                horse = None


# functions for complex conversions:
# 'est_width' - estimated trail width, rlis widths are in feet, osm in
#  meters
def get_est_width(rlis_width, round_res):
    osm_width = None
    plus_bonus = 1.25

    # most rlis widths are in ranges, e.g. 6-9
    if '-' in rlis_width:
        min_, max_ = rlis_width.split('-')
        osm_width = (float(min_)+float(max_)) / 2
    # some specify that they're at least a certain with, e.g. 15+
    elif '+' in rlis_width:
        osm_width = float(rlis_width.replace('+', '')) * plus_bonus
    elif rlis_width == 'Unknown':
        osm_width = None

    # convert to meters and round to supplied unit
    if osm_width:
        osm_width = round(osm_width * 0.3048, round_res) * round_res

    return osm_width


def get_highway_value(equestrian, hike, mtn_bike, on_str_bike, osm_width,
                      road_bike, trl_surface):
    if trl_surface == 'Stairs':
        return 'steps'
    elif on_str_bike == 'Yes':
        return'road'
    # any trail with two or more designated uses is of class 'path'
    elif (hike == 'Yes' and road_bike == 'Yes'
                and trl_surface in ('Hard Surface', 'Decking')
                and osm_width > 3) \
            or (hike == 'Yes' and mtn_bike == 'Yes') \
            or (hike == 'Yes' and equestrian == 'Yes') \
            or (road_bike == 'Yes' and equestrian == 'Yes') \
            or (mtn_bike == 'Yes' and equestrian == 'Yes'):
        return 'path'
    elif road_bike == 'Yes' and trl_surface in ('Hard Surface', 'Decking') \
            and osm_width > 3:
        return 'cycleway'
    elif mtn_bike == 'Yes':
        return 'path'
    elif equestrian == 'Yes':
        return 'bridleway'
    else:
        return 'footway'


def get_bicycle_permissions(on_str_bike, osm_width, road_bike, trl_surface):
    if road_bike == 'No':
        return 'no'
    elif road_bike == 'Yes':
        if (trl_surface in ('Hard Surface', 'Decking')
                and osm_width > 3) or on_str_bike == 'Yes':
            return 'designated'
    elif road_bike == 'Yes':
        return 'yes'
    else:
        return None




if __name__ == __main__:
    translate_trails(TRAILS)
