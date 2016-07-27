import logging
from argparse import ArgumentParser
from collections import defaultdict
from os.path import abspath, basename, dirname, join
from sys import stdout
from time import time

import fiona
from shapely.geometry import mapping, shape
from shapely.ops import unary_union

from rlis2osm.get_data import define_data_paths

start_time = time()


class WayDissolver(object):

    def __init__(self, way_path, fields=None, field_exclude=False):
        self.way_path = way_path
        self.ways = self.open_ways()
        self.fields = self._define_filter_fields(fields, field_exclude)

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

        print path
        print vfs
        ways = fiona.open(path, vfs=vfs)
        return ways

    def close_ways(self):
        """ways should be closed when processing is done"""

        self.ways.close()

    def dissolve_ways(self, write_path=None):
        if not write_path:
            write_path = join(
                dirname(abspath(__name__)), 'data', 'dissolve_{}.shp'.format(
                    basename(self.way_path).split('.')[0]))

        from pprint import pprint
        way1 = self.ways[669]
        pprint(way1)
        coords1 = shape(way1['geometry']).coords
        print coords1[0]
        print coords1[-1], '\n'
        
        way2 = self.ways[670]
        pprint(way2)
        coords2 = shape(way2['geometry']).coords
        print coords2[0]
        print coords2[-1], '\n'

        exit()

        way_groups = self._determine_way_groups()

        metadata = self.ways.meta.copy()
        meta_fields = metadata['schema']['properties']
        self._filter_tags(meta_fields)

        with fiona.open(write_path, 'w', **metadata) as dissolve_shp:
            for group in way_groups:
                geom_list = list()
                for way_id in group:
                    feat = self.ways[way_id]
                    geom = shape(feat['geometry'])
                    geom_list.append(geom)

                dissolve_geom = unary_union(geom_list)
                dissolve_tags = self._filter_tags(feat['properties'])
                dissolve_shp.write(dict(
                    geometry=mapping(dissolve_geom),
                    properties=dissolve_tags
                ))

    def _determine_way_groups(self):
        node_way_map, way_nodes = self._map_end_pts_to_ways()

        print 'determining dissolve groups'
        print 'number of features processed:'

        # a set is used here instead of a list because many lookups must
        # be done on this collection and it reaches a large size
        assigned = LogSet()
        way_groups = list()
        for fid, feat in self.ways.items():
            if fid in assigned:
                continue

            group = list([fid])
            assigned.log_add(fid)
            nodes = way_nodes[fid].values()
            tags = self._filter_tags(feat['properties'])

            while nodes:
                n = nodes.pop()
                connected_ways = node_way_map[n]

                for way_id in connected_ways:
                    if way_id in assigned:
                        continue

                    conn_way = self.ways[way_id]
                    conn_tags = self._filter_tags(conn_way['properties'])

                    if tags == conn_tags:
                        group.append(way_id)
                        assigned.log_add(way_id)

                        for new_node in way_nodes[fid].values():
                            if new_node != n:
                                nodes.append(n)
            way_groups.append(group)
        return way_groups

    def _define_filter_fields(self, filter_fields, exclude):
        """verify that supplied fields exist in the shapefile and define
        the fields that must match for a merge to be allowed
        """

        fields = self.ways[0]['properties'].keys()
        if filter_fields:
            for ff in filter_fields:
                if ff not in fields:
                    logging.error('supplied field: "{}", does not exists in '
                                  'the data, modify the "fields" input and run '
                                  'again'.format(ff))
                    exit()
            if exclude:
                for ff in filter_fields:
                    fields.remove(ff)
            else:
                fields = filter_fields

        return fields

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

    def _filter_tags(self, tags):
        for t in tags:
            if t not in self.fields:
                tags.pop(t)
        return tags


class LogSet(set):
    def __init__(self, dot_value=500, num_value=10000):
        super(self.__class__, self).__init__()
        self.dot_value = dot_value
        self.num_value = num_value

    def log_add(self, list_obj):
        """check the size of the set after adding an element and log the
        size at supplied intervals
        """

        self.add(list_obj)
        counter = len(self)

        # TODO: use logging instead of print here
        if counter % self.num_value == 0:
            stdout.write('{:,}'.format(counter))
            stdout.flush()

            global start_time
            print '    {}'.format(time() - start_time)
            start_time = time()
        elif counter % self.dot_value == 0:
            stdout.write('.')
            stdout.flush()


def process_options():
    parser = ArgumentParser()
    parser.add_argument(
        '-d', '--data_path',
        default=join(dirname(abspath(__name__)), 'data'),
        help='file path at which datasets will be downloaded and written to'
    )
    parser.add_argument()


def main():
    street_fields = [
        'DIRECTION', 'FTYPE', 'F_ZLEV', 'PREFIX',
        'STREETNAME', 'TYPE', 'T_ZLEV']
    streets, trails = define_data_paths(refresh=False)
    streets = join(dirname(abspath(__name__)), 'data', 'streets_test.shp')
    dissolver = WayDissolver(streets, street_fields)
    dissolver.dissolve_ways()
    dissolver.close_ways()


if __name__ == '__main__':
    main()
