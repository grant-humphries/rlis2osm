from collections import defaultdict

import fiona
from shapely.geometry import shape
from shapely.ops import unary_union

TEST_WAYS = '//gisstore/gis/Rlis/STREETS/fwy.shp'


def dissolve_ways(dissolve_fields=None):
    ways = fiona.open(TEST_WAYS)
    map_end_points_to_ways(ways)

    # print ways[0]['properties']
    # exit()

    # assigned = list()
    # for node_id, way_list in node_way_map.items():


def map_end_points_to_ways(ways):
    node_counter = 0
    node_id_map = dict()
    node_way_map = defaultdict(list)

    for fid, feat in ways.items():
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

        fields = feat['properties']
        fields['f_node'] = node_id_map[f_node]
        fields['t_node'] = node_id_map[t_node]

    # return ways, node_way_map

    for fid, feat in ways.items():
        print fid, feat['properties']
        exit()


if __name__ == '__main__':
    dissolve_ways()
