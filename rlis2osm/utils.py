from os.path import basename, splitext

from fiona.crs import from_epsg


def zip_path(path):
    """fiona has the ability open zipped shapefiles, this method
    handles both zipped and unzipped
    """

    vfs = None
    if path.endswith('.zip'):
        vfs = 'zip:///{}'.format(path)
        path = '/{}'.format(basename(path).replace('.zip', '.shp'))
    else:
        path = path

    return dict(path=path, vfs=vfs)


def transform_meta_to_geojson(self, metadata):
    """switch write format to geojson to avoid 10 character field
    name limit of shapefiles
    """

    metadata['crs'] = from_epsg(2913)
    metadata['driver'] = 'GeoJSON'
    metadata['schema']['properties'] = self.OSM_KEYS

    self.dst_path = '{}.geojson'.format(splitext(self.dst_path)[0])

    return metadata
