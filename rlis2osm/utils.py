from os.path import basename

import fiona


class OgrReader(object):
    def __init__(self, path):
        self.path = path
        self.features = self.open_features()

    def open_features(self, path=None):
        """fiona has the ability open zipped shapefiles, this method
        handles both zipped and unzipped
        """

        if self.path.endswith('.zip'):
            vfs = 'zip:///{}'.format(self.path)
            path = '/{}'.format(
                basename(self.path).replace('.zip', '.shp'))
        else:
            vfs = None
            path = self.path

        features = fiona.open(path, vfs=vfs)
        return features

    def close_features(self):
        """features should be closed when processing is done"""

        self.features.close()