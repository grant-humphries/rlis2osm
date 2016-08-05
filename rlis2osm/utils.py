from os.path import basename


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
