from setuptools import find_packages, setup

setup(
    name='rlis2osm',
    version='0.2.0',
    author='Grant Humphries',
    description='',
    entry_points={
        'console_scripts': [
            'ogr2osm = ogr2osm.ogr2osm:main'
        ]
    },
    install_requires=[
        'fiona>=1.7.0',
        'gdal>=2.0.2',
        'ogr2osm>=0.1.0',
        'shapely>=1.5.16'
        'titlecase>=0.8.1'
    ],
    license='GPL',
    long_description=open('README.md').read(),
    packages=find_packages(),
    url='https://github.com/grant-humphries/rlis2osm'
)
