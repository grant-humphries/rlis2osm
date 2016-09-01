import sys
from argparse import ArgumentParser


def process_options():
    parser = ArgumentParser()
    parser.add_argument(
        '-d', 'destination_path'
    )
    parser.add_argument(
        'r', '--refresh_data',
    )

    parser.add_argument(
        '-s', '--source_path',
        help='file path at which datasets will be downloaded and written to'
    )


def main():

    opts = process_options()

    # module execution order: data, expand, translate, combine, dissolve, ogr2osm

if __name__ == '__main__':
    main()