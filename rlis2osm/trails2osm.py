import fiona


OSM_FIELDS = {
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
    'mtb': 'str',
    'name': 'str',
    'operator': 'str',
    'proposed': 'str',
    'surface': 'str',
    'wheelchair': 'str',
    'RLIS:systemname'
}


# rlis trails metadata:
# http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=2404

# 'access' - street access permissions (derived from 'STATUS' field)
general_access_map = {
    'Restricted_Private': 'private',
    'Unknown': 'unknown'
}

# 'bicycle' - bicycle permissions
if  roadbike == 'No':
    return 'no'
elif roadbike == 'Yes':
    if est_width > 3
            and trlsurface in ('Hard Surface', 'Decking')) \
        or onstrbike == 'Yes':
    return 'designated'
elif roadbike == 'Yes':
    then 'yes'
else null end,

# 'est_width' - estimated trail width, rlis widths are in feet, osm in meters
def convert_width(rlis_width, round_res):
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

# 'fee' - trail fee information
if status == 'Open_Fee':
    fee = 'yes'

# 'highway' - trail type
def determine_hwy_type(equestrian, hike, mtnbike, onstrbike, roadbike, trlsurface, est_width):
    if trlsurface == 'Stairs':
        return 'steps' 
    elif onstrbike == 'Yes':
        return'road'
    # any trail with two or more designated uses is a path
    elif (hike == 'Yes' and roadbike == 'Yes' 
                and trlsurface in ('Hard Surface', 'Decking')
                and est_width > 3) \
            or (hike == 'Yes' and mtnbike == 'Yes') \
            or (hike == 'Yes' and equestrian == 'Yes') \
            or (roadbike == 'Yes' and equestrian == 'Yes') \
            or (mtnbike == 'Yes' and equestrian == 'Yes'):
        return 'path'
    elif roadbike == 'Yes' and trlsurface in ('Hard Surface', 'Decking') \
            and est_width > 3:
        return 'cycleway'
    elif mtnbike == 'Yes':
        return 'path'
    elif equestrian == 'Yes': 
        return 'bridleway'
    else:
        return 'footway'

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

# access permission mapping use on equestrian, hike, mtn_bike (horse,
# foot, mtb in osm)
mode_access_map = {
    'No': 'no',
    'Yes': 'designated',
    None: None
}

# 'operator' - managing agency
if agencyname == 'Unknown':
    agencyname = None


# 'RLIS:systemname' - rlis system name, these may eventually be used to create
# relations, but for now don't include this attribute if it is identical one of 
# the trails other names
if systemname == trailname or systemname == sharedname:
    system_name = None


# 'surface' - trail surface
# 'Unknown' and 'Stairs' are valid values, they former will return None
# the way that the dict is called and the latter is used as a part of
# the highway tag, 'Water' trails are exluded
surface_map = {
    'Chunk Wood': 'woodchips',
    'Decking': 'wood',
    'Hard Surface': 'paved',
    'Imported Material': 'compacted',
    'Native Material': 'ground',
    'Snow': 'snow',
    'Unknown': None,
    None: None
}

# 'wheelchair' - accessibility status for disabled persons
access_map = {
    'Accessible': 'yes',
    'Not Accessible': 'no',
    None: None
}

# trails meeting this criteria should be removed
if status == 'Conceptual' or trlsurface == 'Water':
    continue


# 3) Clean-up issues that couldn't be handled on the initial insert

# highway type 'footway' implies foot permissions, it's redundant to have this
# information in the 'foot' tag as well, same goes for 'cycleway' and 'bridleway'
if highway == 'footway':
    foot = None
elif highway = 'cycleway':
    bicycle = None
elif highway = 'bridleway':
    horse = None

