from setuptools import find_packages, setup

# once shapely 1.6 is released numpy will no longer but a project
# requirement, but it still makes things faster so it can be moved
# to the extras_require section

setup(
    name='rlis2osm',
    version='0.2.0',
    author='Grant Humphries',
    dependency_links=[
        'git+https://github.com/grant-humphries/ogr2osm.git#egg=ogr2osm-0.1.0'
    ],
    description='',
    entry_points={
        'console_scripts': [
            'ogr2osm = ogr2osm.main:main',
            'rlis2osm = rlis2osm.main:main'
        ]
    },
    extras_require=dict(
        test=['pprofile>=1.9.2']
    ),
    install_requires=[
        'fiona>=1.6.1',
        'humanize>=0.5.1',
        'numpy>=1.4.1',
        'ogr2osm>=0.1.0',
        'shapely>=1.5.16',
        'titlecase>=0.8.1'
    ],
    license='GPL',
    long_description=open('README.md').read(),
    packages=find_packages(exclude=['rlis2osm.tests*']),
    url='https://github.com/grant-humphries/rlis2osm'
)
