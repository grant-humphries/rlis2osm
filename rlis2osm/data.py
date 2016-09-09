import os
import urllib2
from datetime import datetime
from inspect import getsourcefile
from logging import getLogger
from os.path import abspath, basename, dirname, exists, getmtime, isdir, \
    join, splitext
from posixpath import join as urljoin

log = getLogger(__name__)

RLIS_URL = 'http://library.oregonmetro.gov/rlisdiscovery'
RLIS_TERMS = 'http://rlisdiscovery.oregonmetro.gov/view/terms.htm'


class RlisPaths(object):

    TRIMET_RLIS = '//gisstore/gis/Rlis'

    STREETS = 'streets'
    TRAILS = 'trails'
    BIKES = 'bike_routes'

    def __init__(self, src_dir=None, dst_dir=None):
        self.prj_dir = join(
            dirname(dirname(abspath(getsourcefile(lambda: 0)))), 'data')
        self.src_dir = self._get_source_dir(src_dir)

        feature_paths = self._get_source_paths()
        self.streets = feature_paths[self.STREETS]
        self.trails = feature_paths[self.TRAILS]
        self.bikes = feature_paths[self.BIKES]
        self.dst_dir = self._get_destination_dir(dst_dir)

        if not exists(self.prj_dir):
            os.makedirs(self.prj_dir)

        if not exists(self.dst_dir):
            os.makedirs(self.dst_dir)

    def _get_source_dir(self, src_dir):
        if src_dir:
            pass
        elif exists(self.TRIMET_RLIS):
            src_dir = self.TRIMET_RLIS
        else:
            src_dir = self.prj_dir

        return src_dir

    def _get_source_paths(self):
        if self.src_dir == self.TRIMET_RLIS:
            rlis_map = self._get_rlis_structure()
            streets = join(self.TRIMET_RLIS, rlis_map[self.STREETS],
                           '{}.shp'.format(self.STREETS))
            trails = join(self.TRIMET_RLIS, rlis_map[self.TRAILS],
                          '{}.shp'.format(self.TRAILS))
            bikes = join(self.TRIMET_RLIS, rlis_map[self.BIKES],
                         '{}.shp'.format(self.BIKES))
        else:
            streets = join(self.src_dir, '{}.zip'.format(self.STREETS))
            trails = join(self.src_dir, '{}.zip'.format(self.TRAILS))
            bikes = join(self.src_dir, '{}.zip'.format(self.BIKES))

        return {
            self.STREETS: streets,
            self.TRAILS: trails,
            self.BIKES: bikes
        }

    def _get_destination_dir(self, dst_dir):
        if dst_dir:
            pass
        elif self.src_dir == self.TRIMET_RLIS:
            mod_time = datetime.fromtimestamp(getmtime(self.streets))
            dst_dir = join(
                dirname(self.TRIMET_RLIS), 'PUBLIC', 'OpenStreetMap',
                'RLIS', 'RLIS_osm_data', mod_time.strftime('%Y_%m'))
        else:
            dst_dir = self.prj_dir

        return dst_dir

    def _get_rlis_structure(self):
        rlis_map = dict()

        for dir_ in os.listdir(self.TRIMET_RLIS):
            dir_path = join(self.TRIMET_RLIS, dir_)
            if isdir(dir_path):
                for file_ in os.listdir(dir_path):
                    if file_.endswith('.shp'):
                        name = splitext(file_)[0]
                        rlis_map[name] = dir_

        return rlis_map


def download_rlis(paths, refresh):
    accepted_terms = False

    for ds in (paths.streets, paths.trails, paths.bikes):
        if refresh or not exists(ds):
            if not accepted_terms:
                user_accept = raw_input(
                    'RLIS data is about to be downloaded; in order to use '
                    'this data you must comply with their license, see '
                    'further info here: "{}".  Do you wish to proceed? '
                    '(y/n)\n'.format(RLIS_TERMS))

                if user_accept.lower() not in ('y', 'yes'):
                    "you've declined RLIS's terms, program terminating..."
                    exit()
                else:
                    accepted_terms = True

            download_with_progress(
                urljoin(RLIS_URL, basename(ds)), paths.src_dir)


def download_with_progress(url, write_dir):
    # adapted from: http://stackoverflow.com/questions/22676

    file_name = basename(url)
    file_path = join(write_dir, file_name)
    content = urllib2.urlopen(url)

    meta = content.info()
    file_size = int(meta.getheaders('Content-Length')[0])
    file_size_dl = 0
    block_sz = 8192

    log.info('\nDownload Metadata:'
             '\nfile name: {}'
             '\ntarget directory: {}'
             '\nfile size: {:,} bytes'.format(file_name, write_dir, file_size))

    with open(file_path, 'wb') as file_:

        while True:
            buffer_ = content.read(block_sz)
            if not buffer_:
                break

            file_size_dl += len(buffer_)
            file_.write(buffer_)

            status = '{0:12,d}  [{1:3.2f}%]'.format(
                file_size_dl, file_size_dl * 100. / file_size)
            status += chr(8) * (len(status) + 1)
            print status,
        print ''
    return file_path


def main(refresh=False):
    paths = RlisPaths()

    # do not download/refresh data if user has supplied a source path
    # or if working in TriMet environment
    if paths.src_dir == paths.prj_dir:
        download_rlis(paths, refresh)


if __name__ == '__main__':
    main()
