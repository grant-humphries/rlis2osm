from setuptools import find_packages, setup

setup(
    name='rlis2osm',
    version='0.2.0',
    author='Grant Humphries',
    description='',
    install_requires=[
        'gdal>=1.11.2',
        'titlecase>=0.8.1'
    ],
    license='GPL',
    long_description=open('README.md').read(),
    packages=find_packages(),
    url='https://github.com/grant-humphries/rlis2osm'
)
