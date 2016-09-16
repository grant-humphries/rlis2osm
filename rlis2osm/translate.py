from collections import OrderedDict


class StreetTranslator(object):
    # rlis streets metadata:
    # http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=556

    # several of these mapping are initial written as with key values
    # swapped to be more terse, then flipped
    REV_ACCESS_MAP = {
        'private': (1700, 1740, 1750, 1760, 1800, 1850),
        'no': (5402,)
    }
    # TYPE --> access
    ACCESS_MAP = {i: k for k, v in REV_ACCESS_MAP.items() for i in v}

    REV_HIGHWAY_MAP = {
        'motorway': (1110, 5101, 5201),
        'motorway_link': (1120, 1121, 1122, 1123),
        'primary': (1200, 1300, 5301),
        'primary_link': (1221, 1222, 1223, 1321),
        'secondary': (1400, 5401, 5451),
        'secondary_link': (1421, 1471),
        'tertiary': (1450, 5402, 5500, 5501),
        'tertiary_link': (1521,),
        'residential': (1500, 1550, 1700, 1740, 2000, 8224),
        'service': (1560, 1600, 1750, 1760, 1800, 1850),
        'track': (9000,)
    }
    # TYPE --> highway
    HIGHWAY_MAP = {i: k for k, v in REV_HIGHWAY_MAP.items() for i in v}

    REV_SERVICE_MAP = {
        'alley': (1600,),
        'driveway': (1750, 1850)
    }
    # TYPE --> service
    SERVICE_MAP = {i: k for k, v in REV_SERVICE_MAP.items() for i in v}

    # TYPE --> surface
    SURFACE_MAP = {
        2000: 'unpaved'
    }

    def __init__(self, bike_tag_map=None):
        # provide bike tag mapping to include bicycle tags
        self.bike_tag_map = bike_tag_map
        self.BIKE_FIELDS = None
        self.OSM_FIELDS = None
        self._define_fields()

        # rlis streets fields
        self.direction = None
        self.f_type = None
        self.fz_level = None
        self.local_id = None
        self.prefix = None
        self.street_name = None
        self.type = None
        self.tz_level = None

        # osm tags used in functions
        self.bridge = None
        self.description = None
        self.highway = None
        self.layer = None
        self.name = None
        self.tunnel = None

    def _define_fields(self):
        fields = OrderedDict([
            ('access', 'str'),
            ('bridge', 'str'),
            ('description', 'str'),
            ('highway', 'str'),
            ('layer', 'int'),
            ('name', 'str'),
            ('service', 'str'),
            ('surface', 'str'),
            ('tunnel', 'str')
        ])

        # TODO get rid of rlis specific tags, try to capture the info as a
        # part of the osm standard
        if self.bike_tag_map:
            self.BIKE_FIELDS = {
                'bicycle': 'str',
                'cycleway': 'str',
                'RLIS:bicycle': 'str'
            }
            fields.update(self.BIKE_FIELDS)
            fields = OrderedDict((sorted(fields.items())))

        self.OSM_FIELDS = fields

    def translate(self, attributes):
        self.local_id = attributes['LOCALID']
        self.type = attributes['TYPE']
        
        self.prefix = attributes['PREFIX']
        self.street_name = attributes['STREETNAME']
        self.f_type = attributes['FTYPE']
        self.direction = attributes['DIRECTION']

        self.fz_level = attributes['F_ZLEV']
        self.tz_level = attributes['T_ZLEV']

        self._reset_osm_tags()
        self._set_name_highway_desc()
        self._set_bridge_layer_tunnel()

        tags = {
            'access': self.ACCESS_MAP.get(self.type),
            'bridge': self.bridge,
            'description': self.description,
            'highway': self.highway,
            'layer': self.layer,
            'name': self.name,
            'service': self.SERVICE_MAP.get(self.type),
            'surface': self.SURFACE_MAP.get(self.type),
            'tunnel': self.tunnel
        }

        # add bike tags if map provided
        if self.bike_tag_map:
            bike_tags = {k: None for k in self.BIKE_FIELDS}
            bike_tags = self.bike_tag_map.get(self.local_id, bike_tags)
            tags.update(bike_tags)

        return tags

    def _reset_osm_tags(self):
        self.bridge = None
        self.description = None
        self.highway = None
        self.layer = None
        self.name = None
        self.tunnel = None

    def _set_name_highway_desc(self):
        # handle special cases and concatenate name
        if not self.street_name or self.street_name.lower() == 'unnamed':
            self.name = None
        else:
            name_components = (
                self.prefix,
                self.street_name,
                self.f_type,
                self.direction
            )
            self.name = ' '.join([nc for nc in name_components if nc])

        self.highway = self.HIGHWAY_MAP[self.type]

        # roads of class residential are named, if the type has indicated
        # residential, but there is no name downgrade to service
        if self.highway == 'residential' and not self.name:
            self.highway = 'service'
        # connector streets aka 'links' have descriptions, not names,
        # via osm convention
        elif '_link' in self.highway:
            self.description = self.name
            self.name = None

    def _set_bridge_layer_tunnel(self):
        # layer values coalesced to 1 because in rlis z levels: NULL == 1
        self.fz_level = self.fz_level or 1
        self.tz_level = self.tz_level or 1
        max_z_level = max(self.fz_level, self.tz_level)

        # ground level is 1 for rlis, 0 for osm, rlis skips for 1 to -1
        # and does not use 0 as a value, in osm a way is assumed to have
        # a layer of 0 unless otherwise indicated
        if self.fz_level == self.tz_level:
            if self.fz_level > 1:
                self.layer = self.fz_level - 1
            elif self.fz_level < 0:
                self.layer = self.fz_level
        elif max_z_level > 1:
            self.layer = max_z_level - 1
        elif max_z_level < 0:
            self.layer = min(self.fz_level, self.tz_level)

        # if layer is not zero assume it is a bridge or tunnel
        if not self.layer:
            pass
        elif self.layer > 0:
            self.bridge = 'yes'
        elif self.layer < 0:
            self.tunnel = 'yes'


def get_bike_tag_map(bike_feats):
    # if the bike feature is a street the value in 'BIKEID' with match
    # the 'LOCALID' of the same segment in rlis streets
    bike_tag_map = dict()

    for feat in bike_feats:
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
        # covers 'OTH-CONN', 'OTH-SWLK', 'OTH-XING' values
        elif 'OTH-' in bike_infra or bike_there in ('LT', 'MT', 'HT'):
            bicycle = 'designated'

        if bike_there == 'CA':
            rlis_bicycle = 'caution_area'

        bike_tag_map[bike_id] = {
            'bicycle': bicycle,
            'cycleway': cycleway,
            'RLIS:bicycle': rlis_bicycle
        }

    return bike_tag_map


class TrailsTranslator(object):
    # rlis trails metadata:
    # http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=2404

    # mappings for simple conversions
    ACCESS_MAP = {
        'Restricted_Private': 'private',
        'Unknown': 'unknown'
    }

    # status --> fee
    FEE_MAP = {
        'Open_Fee': 'yes'
    }

    # trl_surface --> surface ('Stairs' and 'Water' are also valid values,
    # but don't map to osm's surface)
    SURFACE_MAP = {
        'Chunk Wood': 'woodchips',
        'Decking': 'wood',
        'Hard Surface': 'paved',
        'Imported Material': 'compacted',
        'Native Material': 'ground',
        'Snow': 'snow',
        'Unknown': None
    }

    # accessible --> wheelchair
    WHEELCHAIR_MAP = {
        'Accessible': 'yes',
        'Not Accessible': 'no'
    }

    OSM_FIELDS = OrderedDict([
        ('abandoned:highway', 'str'),
        ('access', 'str'),
        ('alt_name', 'str'),
        ('bicycle', 'str'),
        ('construction', 'str'),
        ('est_width', 'float'),
        ('fee', 'str'),
        ('foot', 'str'),
        ('highway', 'str'),
        ('horse', 'str'),
        ('name', 'str'),
        ('operator', 'str'),
        ('proposed', 'str'),
        ('surface', 'str'),
        ('wheelchair', 'str'),
    ])

    def __init__(self):
        # rlis trail attributes
        self.accessible = None
        self.agency_name = None
        self.equestrian = None
        self.hike = None
        self.mtn_bike = None
        self.on_str_bike = None
        self.road_bike = None
        self.shared_name = None
        self.status = None
        self.system_name = None
        self.trail_name = None
        self.trl_surface = None
        self.width = None

        # osm tags used in functions
        self.abandoned = None
        self.alt_name = None
        self.bicycle = None
        self.construction = None
        self.est_width = None
        self.foot = None
        self.horse = None
        self.name = None
        self.operator = None
        self.proposed = None

    def translate(self, attributes):
        self.accessible = attributes['ACCESSIBLE']
        self.agency_name = attributes['AGENCYNAME']
        self.equestrian = attributes['EQUESTRIAN']
        self.hike = attributes['HIKE']
        self.mtn_bike = attributes['MTNBIKE']
        self.on_str_bike = attributes['ONSTRBIKE']
        self.road_bike = attributes['ROADBIKE']
        self.shared_name = attributes['SHAREDNAME']
        self.status = attributes['STATUS']
        self.system_name = attributes['SYSTEMNAME']
        self.trail_name = attributes['TRAILNAME']
        self.trl_surface = attributes['TRLSURFACE']
        self.width = attributes['WIDTH']

        # return a flag indicating that the feature should be dropped
        # when meeting these criteria, on street bike segments exist in
        # the streets data so aren't needed here
        if self.on_str_bike == 'Yes' \
                or self.status == 'Conceptual' \
                or self.trl_surface == 'Water':
            return {
                'drop': True,
                'message': 'this trail feature is either a street, a waterway'
                           'or a conceptual trail and should be dropped'
            }

        self._reset_osm_tags()
        self._set_highway_mode()
        self._set_names()

        tags = {
            'abandoned:highway': self.abandoned,
            'access': self.ACCESS_MAP.get(self.status),
            'alt_name': self.alt_name,
            'bicycle': self.bicycle,
            'construction': self.construction,
            'est_width': self.est_width,
            'fee': self.FEE_MAP.get(self.status),
            'foot': self.foot,
            'highway': self.highway,
            'horse': self.horse,
            'name': self.name,
            'operator': self.operator,
            'proposed': self.proposed,
            'surface': self.SURFACE_MAP.get(self.trl_surface),
            'wheelchair': self.WHEELCHAIR_MAP.get(self.accessible),
        }

        return tags

    def _reset_osm_tags(self):
        self.abandoned = None
        self.alt_name = None
        self.bicycle = None
        self.construction = None
        self.est_width = None
        self.foot = None
        self.horse = None
        self.name = None
        self.operator = None
        self.proposed = None

    def _set_highway_mode(self):
        """determine value for highway and mode access tags base on mode
        permissions and trail width and set related highway tags that are
        sometimes transferred its value
        """

        # TODO use the attribute SYSTEMTYPE in the determination of the
        # highway value

        # logic below relies on est with first being set here
        self._set_est_width(0.25)
        path_conditions = [
            self.equestrian == 'Yes',
            self.hike == 'Yes',
            self.mtn_bike == 'Yes',
            self.road_bike == 'Yes' and self.est_width > 3
        ]

        if self.trl_surface == 'Stairs':
            self.highway = 'steps'
        elif n_any(path_conditions, 2):
            self.highway = 'path'

            # horse=no is on everything except path and bridleway,
            # that's not the case for foot and bike
            if self.equestrian == 'Yes':
                self.horse = 'designated'
            elif self.equestrian == 'No':
                self.horse = 'no'

            if self.hike:
                self.foot = 'designated'

            if self.road_bike or self.mtn_bike:
                self.bicycle = 'designated'
        elif self.road_bike == 'Yes':
            self.highway = 'cycleway'
        elif self.equestrian == 'Yes':
            self.highway = 'bridleway'
        else:
            self.highway = 'footway'

            if self.road_bike or self.mtn_bike:
                self.bicycle = 'yes'

        if self.hike == 'No':
            self.foot = 'no'

        if ((self.mtn_bike == 'No' and self.road_bike != 'Yes') or
                (self.road_bike == 'No' and self.mtn_bike != 'Yes')):
            self.bicycle = 'no'

        # for certain status values the highway value should be moved
        # to others keys
        if self.status == 'Decommissioned':
            self.abandoned = self.highway
            self.highway = None
        elif self.status == 'Planned':
            self.proposed = self.highway
            self.highway = 'proposed'
        elif self.status == 'Under construction':
            self.construction = self.highway
            self.highway = 'construction'

    def _set_est_width(self, resolution):
        temp_width = None
        plus_bonus = 1.25

        if not self.width:
            self.est_width = None
            return
        # most rlis widths are in ranges, e.g. 6-9
        elif '-' in self.width:
            min_, max_ = self.width.split('-')
            temp_width = (float(min_)+float(max_)) / 2
        # some specify that they're at least a certain with, e.g. 15+
        elif '+' in self.width:
            temp_width = float(self.width.replace('+', '')) * plus_bonus
        elif self.width == 'Unknown':
            self.est_width = None
            return

        # convert to meters and round to supplied unit
        if temp_width:
            self.est_width = (
                round(temp_width * 0.3048 / resolution) * resolution)

    def _set_names(self):
        self.name = self.trail_name or self.shared_name or self.system_name

        # order of shared and system matters here shared name takes
        # precedence over system name
        for alt_name in (self.shared_name, self.system_name):
            if alt_name and alt_name != self.name:
                self.alt_name = alt_name
                break

        if self.agency_name != 'Unknown':
            self.operator = self.agency_name


def n_any(iterable, n):
    trues = 0
    for element in iterable:
        if element:
            trues += 1
            if trues >= n:
                return True

    return False
