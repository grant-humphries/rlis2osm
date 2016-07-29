import os
import urllib2
from os.path import abspath, basename, dirname, exists, isdir, join, splitext

RLIS_URL = 'http://library.oregonmetro.gov/rlisdiscovery'
RLIS_TERMS = 'http://rlisdiscovery.oregonmetro.gov/view/terms.htm'
TRIMET_RLIS = '//gisstore/gis/Rlis/adghag'

STREETS = 'streets'
TRAILS = 'trails'
BIKE_ROUTES = 'bike_routes'


def define_data_paths(refresh=True, data_path=None):
    if exists(TRIMET_RLIS):
        rlis_map = get_rlis_dir_structure()

        streets = join(
            TRIMET_RLIS, rlis_map[STREETS], '{}.shp'.format(STREETS))
        trails = join(
            TRIMET_RLIS, rlis_map[TRAILS], '{}.shp'.format(TRAILS))
        bike_routes = join(
            TRIMET_RLIS, rlis_map[BIKE_ROUTES], '{}.shp'.format(BIKE_ROUTES))
    else:
        if not data_path:
            data_path = join(dirname(abspath(__name__)), 'data')

        if not exists(data_path):
            os.makedirs(data_path)

        streets = join(data_path, '{}.zip'.format(STREETS))
        trails = join(data_path, '{}.zip'.format(TRAILS))
        bike_routes = join(data_path, '{}.zip'.format(BIKE_ROUTES))

        accepted_terms = False
        for ds in (streets, trails, bike_routes):
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
                    '{}/{}'.format(RLIS_URL, basename(ds)), data_path)

    return streets, trails, bike_routes


def get_rlis_dir_structure():
    rlis_map = dict()

    for dir_ in os.listdir(TRIMET_RLIS):
        dir_path = join(TRIMET_RLIS, dir_)
        if isdir(dir_path):
            for file_ in os.listdir(dir_path):
                if file_.endswith('.shp'):
                    name = splitext(file_)[0]
                    rlis_map[name] = dir_

    return rlis_map


def download_with_progress(url, write_dir):
    # adapted from: http://stackoverflow.com/questions/22676

    file_name = basename(url)
    file_path = join(write_dir, file_name)
    content = urllib2.urlopen(url)

    meta = content.info()
    file_size = int(meta.getheaders('Content-Length')[0])
    file_size_dl = 0
    block_sz = 8192

    print '\nDownload Info:'
    print 'file name: {} '.format(file_name)
    print 'target directory: {}'.format(write_dir)
    print 'file size: {:,} bytes'.format(file_size)

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


if __name__ == '__main__':
    define_data_paths()
