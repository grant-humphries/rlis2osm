import logging
from argparse import ArgumentParser
from collections import defaultdict
from os.path import abspath, basename, dirname, join
from sys import stdout
from time import time

import fiona
from shapely.geometry import mapping, shape
from shapely.ops import unary_union

from rlis2osm.data import define_data_paths

start_time = time()


class WayDissolver(object):

    def __init__(self, path, fields=None, field_exclude=False):
        self.path = path
        self.ways =
        self.fields = self._define_filter_fields(fields, field_exclude)

    def dissolve_ways(self, write_path=None):
        if not write_path:
            write_path = join(
                dirname(abspath(__name__)), 'data', 'dissolve_{}.shp'.format(
                    basename(self.path).split('.')[0]))

        way_groups = self._determine_way_groups()

        metadata = self.features.meta.copy()
        meta_fields = metadata['schema']['properties']
        self._filter_tags(meta_fields)

        with fiona.open(write_path, 'w', **metadata) as dissolve_shp:
            for group in way_groups:
                geom_list = list()
                for way_id in group:
                    feat = self.features[way_id]
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
        for fid, feat in self.features.items():
            if fid in assigned:
                continue

            group = list([fid])
            assigned.log_add(fid)
            nodes = way_nodes[fid].values()
            tags = self._filter_tags(feat['properties'])

            while nodes:
                n = nodes.pop()
                connected_ways = node_way_map[n]

                for connect_id in connected_ways:
                    if connect_id in assigned:
                        continue

                    connect_way = self.features[connect_id]
                    connect_tags = self._filter_tags(connect_way['properties'])

                    if tags == connect_tags:
                        group.append(connect_id)
                        assigned.log_add(connect_id)

                        connect_nodes = way_nodes[connect_id].values()
                        for cn in connect_nodes:
                            if cn != n and cn not in nodes:
                                nodes.append(cn)
            way_groups.append(group)
        return way_groups

    def _define_filter_fields(self, filter_fields, exclude):
        """verify that supplied fields exist in the shapefile and define
        the fields that must match for a merge to be allowed
        """

        fields = self.features[0]['properties'].keys()
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

        for fid, feat in self.features.items():
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
    dissolver = WayDissolver(streets, street_fields)
    dissolver.dissolve_ways()
    dissolver.close_features()


if __name__ == '__main__':
    main()
