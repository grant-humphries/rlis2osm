from collections import OrderedDict
from os.path import basename, join, splitext

import fiona
from fiona.crs import from_epsg

from rlis2osm.data import RlisPaths
from rlis2osm.utils import zip_path


class Translator(object):
    OSM_KEYS = None

    def __init__(self, src_path, dst_dir):
        self.src_path = src_path
        self.dst_dir = dst_dir
        self.dst_path = join(
            dst_dir, 'translated_{}'.format(basename(src_path)))

    def _translate_metadata(self, metadata):
        """switch write format to geojson to avoid 10 character field
        name limit of shapefiles
        """

        metadata['crs'] = from_epsg(2913)
        metadata['driver'] = 'GeoJSON'
        metadata['schema']['properties'] = self.OSM_KEYS

        self.dst_path = '{}.geojson'.format(splitext(self.dst_path)[0])

        return metadata


class StreetTranslator(Translator):
    # type --> surface
    SURFACE_MAP = {
        2000: 'unpaved'
    }

    # below are reverse mappings, these are less verbose in this format
    # and are subsequently swapped into the form needed for lookups

    RV_ACCESS_MAP = {
        'private': [1700, 1740, 1750, 1760, 1800, 1850],
        'no': [5402]
    }
    # type --> access
    ACCESS_MAP = {i: k for k, v in RV_ACCESS_MAP.items() for i in v}

    RV_SERVICE_MAP = {
        'alley': [1600],
        'driveway': [1750, 1850]
    }
    # type --> service
    SERVICE_MAP = {i: k for k, v in RV_SERVICE_MAP.items() for i in v}

    RV_HIGHWAY_MAP = {
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
    # type --> highway
    HIGHWAY_MAP = {i: k for k, v in RV_HIGHWAY_MAP.items() for i in v}

    OSM_KEYS = OrderedDict([
        ('access', 'str'),
        ('bicycle', 'str'),
        ('bridge', 'str'),
        ('cycleway', 'str'),
        ('description', 'str'),
        ('highway', 'str'),
        ('layer', 'int'),
        ('name', 'str'),
        ('service', 'str'),
        ('surface', 'str'),
        ('tunnel', 'str'),
        ('RLIS:bicycle', 'str')
    ])

    def __init__(self, src_path, dst_dir):
        super(self.__class__, self).__init__(src_path, dst_dir)

        # rlis streets fields
        self.direction = None
        self.f_type = None
        self.fz_level = None
        self.local_id = None
        self.prefix = None
        self.street_name = None
        self.type = None
        self.tz_level = None

    def translate_streets(self, bike_tags_map):
        rlis_streets = fiona.open(self.src_path)

        metadata = rlis_streets.meta.copy()
        metadata = self._translate_metadata(metadata)

        with fiona.open(self.dst_path, 'w', **metadata) as osm_streets:
            for feat in rlis_streets:
                tags = feat['properties']
                self.direction = tags['DIRECTION']
                self.fz_level = tags['F_ZLEV']
                self.local_id = tags['LOCALID']
                self.prefix = tags['PREFIX']
                self.street_name = tags['STREETNAME']
                self.type = tags['TYPE']
                self.tz_level = tags['T_ZLEV']

                name = '{} {} {} {}'.format(self.prefix, self.street_name, self.f_type, self.direction).trim()
                highway = self._get_highway_value()
                bike_tags = bike_tags_map.get(self.local_id, dict())
                layer_tags = self._layer_passage_from_z()
                description = self._name_adjustments(highway)

                osm_tags = {
                    'access': self.ACCESS_MAP.get(self.type),
                    'bicycle': bike_tags.get('bicycle'),
                    'bridge': layer_tags['bridge'],
                    'cycleway': bike_tags.get('cycleway'),
                    'description': description,
                    'highway': highway,
                    'layer': layer_tags['layer'],
                    'name': self.name,
                    'service': self.SERVICE_MAP.get(self.type),
                    'surface': self.SURFACE_MAP.get(self.type),
                    'tunnel': layer_tags['tunnel'],
                    'RLIS:bicycle': bike_tags.get('rlis_bicycle'),
                }
                
                feat['properties'] = osm_tags
                osm_streets.write(feat)

        rlis_streets.close()

    def _get_highway_value(self):
        highway = self.HIGHWAY_MAP[self.type]

        # roads of class residential are named, if the type has indicated
        # residential, but there is no name downgrade to service
        if highway == 'residential' and not self.name:
            highway = 'service'

        return highway

    def _layer_passage_from_z(self):
        layer, bridge, tunnel = None, None, None

        # layer values coalesced to 1 because in rlis z levels: NULL == 1
        self.fz_level = self.fz_level or 1
        self.tz_level = self.tz_level or 1
        max_z_level = max(self.fz_level, self.tz_level)

        # ground level is 1 for rlis, 0 for osm, rlis skips for 1 to -1
        # and does not use 0 as a value, in osm a way is assumed to have
        # a layer of 0 unless otherwise indicated
        if self.fz_level == self.tz_level:
            if self.fz_level > 1:
                layer = self.fz_level - 1
            elif self.fz_level < 0:
                layer = self.fz_level
        elif max_z_level > 1:
            layer = max_z_level - 1
        elif max_z_level < 0:
            layer = min(self.fz_level, self.tz_level)

        # if layer is not zero assume it is a bridge or tunnel
        if not layer:
            pass
        elif layer > 0:
            bridge = 'yes'
        elif layer < 0:
            tunnel = 'yes'

        return dict(layer=layer, bridge=bridge, tunnel=tunnel)

    def _name_adjustments(self, highway):
        # motorway_link's have descriptions, not names, via osm convention
        description = None
        if highway == 'motorway_link':
            description = self.name
            self.name = None

        return description


# this may help in determining how to merge connected segments with
# common attribute with python, replicating what is done with postgis
# below: http://gis.stackexchange.com/questions/61474/


class BikeTranslator(Translator):

    def get_bike_tags(self):
        bike_tags = dict()

        with fiona.open(**zip_path(self.src_path)) as routes:
            for feat in routes:
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

                bike_tags[bike_id] = dict(
                    bicycle=bicycle,
                    cycleway=cycleway,
                    rlis_bicycle=rlis_bicycle
                )

            return bike_tags


# rlis trails metadata:
# http://rlisdiscovery.oregonmetro.gov/metadataviewer/display.cfm?meta_layer_id=2404

class TrailsTranslator(Translator):

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

    # TODO rethink how mountain bike info is handled given that mtb is not a valid key
    OSM_KEYS = OrderedDict([
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
        ('RLIS:system_name', 'str')
    ])

    def __init__(self, src_path, dst_dir):
        super(self.__class__, self).__init__(src_path, dst_dir)

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

    def translate_trails(self):
        rlis_trails = fiona.open(**zip_path(self.src_path))

        metadata = rlis_trails.meta.copy()
        metadata = self._translate_metadata(metadata)

        with fiona.open(self.dst_path, 'w', **metadata) as osm_trails:
            for feat in rlis_trails:
                tags = feat['properties']
                self.accessible = tags['ACCESSIBLE']
                self.agency_name = tags['AGENCYNAME']
                self.equestrian = tags['EQUESTRIAN']
                self.hike = tags['HIKE']
                self.mtn_bike = tags['MTNBIKE']
                self.on_str_bike = tags['ONSTRBIKE']
                self.road_bike = tags['ROADBIKE']
                self.shared_name = tags['SHAREDNAME']
                self.status = tags['STATUS']
                self.system_name = tags['SYSTEMNAME']
                self.trail_name = tags['TRAILNAME']
                self.trl_surface = tags['TRLSURFACE']
                self.width = tags['WIDTH']

                # remove segments meeting these criteria, on street bike
                # segments exists in the streets data so aren't needed here
                if self.on_str_bike == 'Yes' \
                        or self.status == 'Conceptual' \
                        or self.trl_surface == 'Water':
                    continue

                self._name_adjustments()

                # these osm tags are needed as part of the computation of
                # other tags
                est_width = self._get_est_width(0.25)
                highway, mode_tags = self._get_mode_tags(est_width)
                highway_tags = self._highway_adjustments(highway)

                osm_tags = {
                    'abandoned:highway': highway_tags['abandoned'],
                    'access': self.ACCESS_MAP.get(self.status),
                    'alt_name': self.shared_name,
                    'bicycle': mode_tags['bicycle'],
                    'construction': highway_tags['construction'],
                    'est_width': est_width,
                    'fee': self.FEE_MAP.get(self.status),
                    'foot': mode_tags['foot'],
                    'highway': highway_tags['highway'],
                    'horse': mode_tags['horse'],
                    'name': self.trail_name,
                    'operator': self.agency_name,
                    'proposed': highway_tags['proposed'],
                    'surface': self.SURFACE_MAP.get(self.trl_surface),
                    'wheelchair': self.WHEELCHAIR_MAP.get(self.accessible),
                    'RLIS:system_name': self.system_name
                }

                feat['properties'] = osm_tags
                osm_trails.write(feat)

        rlis_trails.close()

    def _get_est_width(self, resolution):
        est_width = None
        plus_bonus = 1.25

        if not self.width:
            pass
        # most rlis widths are in ranges, e.g. 6-9
        elif '-' in self.width:
            min_, max_ = self.width.split('-')
            est_width = (float(min_)+float(max_)) / 2
        # some specify that they're at least a certain with, e.g. 15+
        elif '+' in self.width:
            est_width = float(self.width.replace('+', '')) * plus_bonus
        elif self.width == 'Unknown':
            est_width = None

        # convert to meters and round to supplied unit
        if est_width:
            est_width = round(est_width * 0.3048 * resolution) / resolution

        return est_width

    def _get_mode_tags(self, est_width):
        """determine value for highway and mode access tags base on mode
        permissions and trail width
        """

        bicycle, foot, horse = None, None, None
        path_conditions = [
            self.equestrian == 'Yes',
            self.hike == 'Yes',
            self.mtn_bike == 'Yes',
            self.road_bike == 'Yes' and est_width > 3
        ]

        if self.trl_surface == 'Stairs':
            highway = 'steps'
        elif n_any(path_conditions, 2):
            highway = 'path'

            if self.equestrian == 'Yes':
                horse = 'designated'
            elif self.equestrian == 'No':
                horse = 'no'

            if self.hike:
                foot = 'designated'

            if self.road_bike or self.mtn_bike:
                bicycle = 'designated'
        elif self.road_bike == 'Yes':
            highway = 'cycleway'
        elif self.equestrian == 'Yes':
            highway = 'bridleway'
        else:
            highway = 'footway'

            if self.road_bike:
                bicycle = 'yes'

        if self.hike == 'No':
            foot = 'no'

        if ((self.mtn_bike == 'No' and self.road_bike != 'Yes') or
                (self.road_bike == 'No' and self.mtn_bike != 'Yes')):
            bicycle = 'no'

        return highway, dict(bicycle=bicycle, foot=foot, horse=horse)

    def _name_adjustments(self):
        # name adjustments, no duplicate names
        if self.shared_name == self.trail_name:
            self.shared_name = None

        if self.system_name in (self.trail_name, self.shared_name):
            self.system_name = None

        if self.agency_name == 'Unknown':
            self.agency_name = None

    def _highway_adjustments(self, highway):
        # for certain status values the highway value should be
        # moved to others keys

        abandoned, construction, proposed = None, None, None
        if self.status == 'Decommissioned':
            abandoned = highway
            highway = None
        elif self.status == 'Planned':
            proposed = highway
            highway = 'proposed'
        elif self.status == 'Under construction':
            construction = highway
            highway = 'construction'

        return dict(
            highway=highway,
            abandoned=abandoned,
            construction=construction,
            proposed=proposed
        )


def n_any(iterable, n):
    trues = 0
    for element in iterable:
        if element:
            trues += 1
            if trues >= n:
                return True

    return False


def main():
    paths = RlisPaths()

    # streets_trans = StreetTranslator(paths.streets, paths.prj_dir)
    # bike_trans = BikeTranslator(paths.bikes, paths.prj_dir)
    # bike_tags = bike_trans.get_bike_tags()
    # streets_trans.translate_streets(bike_tags)

    trails_trans = TrailsTranslator(paths.trails, paths.prj_dir)
    trails_trans.translate_trails()

if __name__ == '__main__':
    main()
