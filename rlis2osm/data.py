import logging as log
import os
import sys
import urllib2
from datetime import datetime
from inspect import getsourcefile
from os.path import abspath, basename, dirname, exists, getmtime, isdir, \
    join, splitext
from posixpath import join as urljoin
from sys import stdout

from humanize import naturalsize

logger = log.getLogger(__name__)

RLIS_URL = 'http://library.oregonmetro.gov/rlisdiscovery'
RLIS_TERMS = 'http://rlisdiscovery.oregonmetro.gov/view/terms.htm'
TRIMET_RLIS = '//gisstore/gis/Rlis'


class RlisPaths(object):

    STREETS = 'streets'
    TRAILS = 'trails'
    BIKES = 'bike_routes'

    def __init__(self, src_dir=None, dst_dir=None):
        module_path = abspath(getsourcefile(lambda: 0))
        self.prj_dir = join(dirname(dirname(module_path)))
        self.data_dir = join(self.prj_dir, 'data')
        self.src_dir = self._get_source_dir(src_dir)

        feature_paths = self._get_source_paths()
        self.streets = feature_paths[self.STREETS]
        self.trails = feature_paths[self.TRAILS]
        self.bikes = feature_paths[self.BIKES]

        # self.streets must be set before self.dst_dir can be determined
        self.dst_dir = self._get_destination_dir(dst_dir)
        self.combined = join(self.data_dir, 'combined.shp')
        self.dissolved = join(self.data_dir, 'dissolved.shp')
        self.osm = join(self.dst_dir, 'rlis.osm')

        for directory in (self.data_dir, self.dst_dir):
            if not exists(directory):
                os.makedirs(directory)

    def _get_source_dir(self, src_dir):
        if src_dir:
            pass
        elif exists(TRIMET_RLIS):
            src_dir = TRIMET_RLIS
        else:
            src_dir = self.data_dir

        return src_dir

    def _get_destination_dir(self, dst_dir):
        if dst_dir:
            pass
        elif self.src_dir == TRIMET_RLIS:
            mod_time = datetime.fromtimestamp(getmtime(self.streets))
            dst_dir = join(
                dirname(self.src_dir),
                'PUBLIC',
                'OpenStreetMap',
                'RLIS',
                'RLIS_osm_data',
                mod_time.strftime('%Y_%m'))
        else:
            dst_dir = self.data_dir

        return dst_dir

    def _get_source_paths(self):
        if self.src_dir == TRIMET_RLIS:
            rlis_map = self._get_rlis_structure()
            streets = join(self.src_dir, rlis_map[self.STREETS],
                           '{}.shp'.format(self.STREETS))
            trails = join(self.src_dir, rlis_map[self.TRAILS],
                          '{}.shp'.format(self.TRAILS))
            bikes = join(self.src_dir, rlis_map[self.BIKES],
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

    def _get_rlis_structure(self):
        rlis_map = dict()

        for dir_ in os.listdir(TRIMET_RLIS):
            dir_path = join(TRIMET_RLIS, dir_)
            if isdir(dir_path):
                for file_ in os.listdir(dir_path):
                    if file_.endswith('.shp'):
                        name = splitext(file_)[0]
                        rlis_map[name] = dir_

        return rlis_map


def download_rlis(paths, refresh=False):
    accepted_terms = False

    for ds in (paths.streets, paths.trails, paths.bikes):
        if refresh or not exists(ds):
            if not accepted_terms:
                user_accept = raw_input(
                    'RLIS data is about to be downloaded, in order to use '
                    'it you must comply with their license, see details on the '
                    'terms here: "{}".  Do you wish to proceed? '
                    '(y/n)\n'.format(RLIS_TERMS))

                if user_accept.lower() not in ('y', 'yes'):
                    logger.critical("you've declined RLIS's terms, program "
                                    'terminating...')
                    sys.exit(1)
                else:
                    accepted_terms = True

            download_with_progress(
                urljoin(RLIS_URL, basename(ds)), paths.src_dir)


def download_with_progress(url, write_dir):
    file_name = basename(url)
    file_path = join(write_dir, file_name)
    content = urllib2.urlopen(url)

    meta = content.info()
    file_size = int(meta.getheaders('Content-Length')[0])

    download_size = 0
    block_size = 8192
    logged = 0

    logger.info('Metadata for Download:')
    logger.info('target file: {}'.format(file_path))
    logger.info('file size: {}'.format(naturalsize(file_size)))
    logger.info('percent completed:')

    with open(file_path, 'wb') as file_:
        while True:
            buffer_ = content.read(block_size)
            if not buffer_:
                break

            file_.write(buffer_)
            if not logger.isEnabledFor(log.INFO):
                continue

            download_size += len(buffer_)
            pct_complete = int(round(download_size / file_size * 100))
            pct_range = pct_complete + 1
            for i in range(logged, pct_range):
                if i % 10 == 0:
                    stdout.write(str(i))

                    if i == 100:
                        stdout.write('\n')
                elif i % 1 == 0:
                    stdout.write('.')

                stdout.flush()
            logged = pct_range

    return file_path


def main(src_dir=None, dst_dir=None, refresh=False):
    paths = RlisPaths(src_dir, dst_dir)

    # do not download/refresh data if user has supplied a source path
    # or if working in TriMet environment
    if paths.src_dir != TRIMET_RLIS:
        download_rlis(paths, refresh)

    return paths

if __name__ == '__main__':
    main()
