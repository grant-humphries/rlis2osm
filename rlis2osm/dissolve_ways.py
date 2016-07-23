import logging
from os.path import abspath, basename, dirname, exists, join
from collections import defaultdict

import fiona
from shapely.geometry import shape
from shapely.ops import unary_union

TRIMET_RLIS = '//gisstore/gis/Rlis'
RLIS_URL = 'http://library.oregonmetro.gov/rlisdiscovery'
STREETS = 'streets.zip'
TRAILS = 'trails.zip'
RLIS_TERMS = 'http://rlisdiscovery.oregonmetro.gov/view/terms.htm'
TEST_WAYS = join(dirname(abspath(__name__)), 'data', 'fwy.zip')


def download_rlis():
    pass


def get_data_paths():
    if exists(TRIMET_RLIS):
        streets_shp = join(TRIMET_RLIS, 'STREETS', 'streets.shp')
        trails_shp = join(TRIMET_RLIS, 'TRANSIT', 'trails.shp')
    else:
        streets_shp = join(dirname(abspath(__name__)), )


class WayDissolver(object):

    def __init__(self, way_path, tags=None, tag_exclude=True):
        self.way_path = way_path
        self.ways = self.open_ways()
        self.tags = self._define_filter_tags(tags, tag_exclude)

    def open_ways(self):
        """fiona has the ability open zipped shapefiles, this method
        handles both zipped and unzipped
        """

        file_ext = self.way_path.split('.')[-1]
        if file_ext == 'zip':
            vfs = 'zip:///{}'.format(self.way_path)
            path = '/{}'.format(
                basename(self.way_path).replace('.zip', '.shp'))
        else:
            vfs = None
            path = self.way_path

        ways = fiona.open(path, vfs=vfs)
        return ways

    def close_ways(self):
        """ways should be closed when processing is done"""

        self.ways.close()

    def _define_filter_tags(self, tags, tag_exclude):
        """verify that supplied fields exist in the shapefile and define
        the fields that must match for a merge to be allowed
        """

        fields = self.ways[0]['properties'].keys()
        if tags:
            for t in tags:
                if t not in fields:
                    logging.error('supplied field: "{}", does not exists in '
                                  'the data, modify the "tags" input and run '
                                  'again'.format(t))
                    exit()
            if tag_exclude:
                for t in tags:
                    fields.pop(t)
            else:
                fields = tags

        return fields

    def dissolve_ways(self):
        node_way_map, way_nodes = self._map_end_pts_to_ways()

        assigned = list()
        way_groups = list()
        for fid, feat in self.ways.items():
            if fid in assigned:
                continue

            group = list(fid)
            nodes = way_nodes[fid].values()
            tags = feat['properties']

            while nodes:
                n = nodes.pop()
                connected_ways = node_way_map[n]
                connected_ways.pop(n)

                for way_id in connected_ways:
                    if way_id in assigned:
                        continue

                    if feat['properties'] == self.ways[way_id]['properties']:
                        this_group.add(way_id)
                        for new_node in way_nodes[fid].values():
                            if new_node != n:
                                nodes.append(n)
                print nodes
            exit()

    def _map_end_pts_to_ways(self):
        node_counter = 0
        node_id_map = dict()
        node_way_map = defaultdict(list)
        way_nodes = dict()

        for fid, feat in self.ways.items():
            geom = shape(feat['geometry'])
            coords = list(geom.coords)
            f_node = coords[0]
            t_node = coords[-1]

            for node in (f_node, t_node):
                if node not in node_id_map:
                    node_id_map[node] = node_counter
                    node_counter += 1

                node_id = node_id_map[node]
                node_way_map[node_id].append(fid)

            way_nodes[fid] = {
                'f': node_id_map[f_node],
                't': node_id_map[t_node]
            }

        return node_way_map, way_nodes


def main():
    base_path = join(dirname(abspath(__name__)), 'data')
    zip_path = join(base_path, 'fwy.zip')
    shp_path = join(base_path, 'unzipped', 'fwy.shp')

    zip_dissolver = WayDissolver(zip_path)
    shp_dissolver = WayDissolver(shp_path)

    zip_dissolver.close_ways()
    shp_dissolver.close_ways()


if __name__ == '__main__':
    main()
