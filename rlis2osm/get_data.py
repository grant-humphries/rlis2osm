import os
import urllib2
from os.path import abspath, basename, dirname, exists, join

RLIS_URL = 'http://library.oregonmetro.gov/rlisdiscovery'
RLIS_TERMS = 'http://rlisdiscovery.oregonmetro.gov/view/terms.htm'
TRIMET_DRIVE = '//gisstore/gis'

STREETS = 'streets'
TRAILS = 'trails'


def define_data_paths(refresh=True, data_path=None):
    if exists(TRIMET_DRIVE):
        trimet_rlis = join(TRIMET_DRIVE, 'Rlis')
        streets = join(trimet_rlis, 'STREETS', '{}.shp'.format(STREETS))
        trails = join(trimet_rlis, 'TRANSIT', '{}.shp'.format(TRAILS))
    else:
        if not data_path:
            data_path = join(dirname(abspath(__name__)), 'data')

        if not exists(data_path):
            os.makedirs(data_path)

        if refresh:
            # TODO improve language in warming, implement prompt
            print 'RLIS data is about to be downloaded in order to use this' \
                  'data you must comply with their license, see more info' \
                  'here: {}, do you wish to proceed?'.format(RLIS_TERMS)

            for ds in (STREETS, TRAILS):
                download_with_progress(
                    '{}/{}.zip'.format(RLIS_URL, ds), data_path)

        streets = join(data_path, '{}.zip'.format(STREETS))
        trails = join(data_path, '{}.zip'.format(TRAILS))

    return streets, trails


def download_with_progress(url, write_dir):
    # adapted from: http://stackoverflow.com/questions/22676

    file_name = basename(url)
    file_path = join(write_dir, file_name)
    content = urllib2.urlopen(url)
    f = open(file_path, 'wb')
    meta = u.info()
    file_size = int(meta.getheaders('Content-Length')[0])
    print '\ndownload directory: {}'.format(write_dir)
    print 'download file name: {} '.format(file_name)
    print 'download size: {:,} bytes'.format(file_size)

    file_size_dl = 0
    block_sz = 8192
    while True:
        buffer_ = u.read(block_sz)
        if not buffer_:
            break

        file_size_dl += len(buffer_)
        f.write(buffer_)

        status = '{0:12,d}  [{1:3.2f}%]'.format(
            file_size_dl, file_size_dl * 100. / file_size)
        status += chr(8) * (len(status) + 1)
        print status,

    f.close()

    return file_path


def main():
    define_data_paths()


if __name__ == '__main__':
    main()