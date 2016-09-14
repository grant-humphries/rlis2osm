import logging
from collections import defaultdict
from sys import stdout
from time import time

import fiona
from shapely.geometry import mapping, shape
from shapely.ops import unary_union

from rlis2osm.data import RlisPaths
from rlis2osm.utils import zip_path

start_time = time()


class WayDissolver(object):

    def __init__(self, ):
        self.ways = None
        self.fields = None

    def dissolve_ways(self, src_path, dst_path, fields=None, exclude=False):
        self.ways = fiona.open(**zip_path(src_path))
        self.fields = self._define_filter_fields(fields, exclude)

        way_groups = self._determine_way_groups()
        metadata = self.ways.meta.copy()
        meta_fields = metadata['schema']['properties']
        self._filter_tags(meta_fields)

        with fiona.open(dst_path, 'w', **metadata) as dissolve_shp:
            for group in way_groups:
                geom_list = list()
                for way_id in group:
                    feat = self.ways[way_id]
                    geom = shape(feat['geometry'])
                    geom_list.append(geom)

                group_tags = self.ways[group[0]]['properties']
                dissolve_geom = unary_union(geom_list)
                dissolve_tags = self._filter_tags(group_tags)
                dissolve_shp.write(dict(
                    geometry=mapping(dissolve_geom),
                    properties=dissolve_tags
                ))

        self.ways.close()
        return dst_path

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

                for connect_id in connected_ways:
                    if connect_id in assigned:
                        continue

                    connect_way = self.ways[connect_id]
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
        """verify that supplied fields exists in the shapefile and define
        the fields that must match for a merge to be allowed
        """

        fields = self.ways[0]['properties'].keys()
        if filter_fields:
            for ff in filter_fields:
                if ff not in fields:
                    # TODO raise error here instead
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


def main():
    paths = RlisPaths()
    dissolver = WayDissolver(paths.streets, paths.prj_dir)
    dissolver.dissolve_ways()


if __name__ == '__main__':
    main()
