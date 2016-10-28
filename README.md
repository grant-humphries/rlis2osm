
# rlis2osm
![rlis2osm in josm](./images/rlis2osm_in_josm_slim.png?raw=true)
<small>converted RLIS data loaded in the JOSM editor</small>

### Purpose
The majority of Oregon Metro's Regional Land Information System ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including the street, trail and bicycle centerline data that is used in this project, is now under the same license as OpenStreetMap ([OSM](osm.org)): the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means that edits to OSM that are derived from RLIS are fully compliant with OpenStreetMap's contribution terms.  Significant resources go into keeping RLIS accurate and up-to-date for the Portland metro region which makes it great resources for the improvement of OSM.

However, RLIS and OSM use a significantly different methodologies to classify attributes and RLIS is released in shapefile format which is not ideal for comparison to existing OSM data in an editing environment.  The code here converts the attributes, segmentation (splitting connected lines only when attributes differ, not at each intersection), and geodata type (.shp --> .osm format) of RLIS data to a state that mirrors OSM as closely as possible.

Because RLIS is updated and released quarterly the conversion needs to be executed often to keep pace with those improvement.  Once you have the project dependencies in place this tool makes that process a matter of running a single console script.

### Converting the Data
This conversion can be carried out in a few minutes once the needed python packages are properly installed, but the tricky part of this process can be getting those dependencies in place.  If you're not interested in setting up the environment and running the code, but would like to use the data to improve OSM, skip to the [Using the Data](#using-the-data) section below.

#### Dependencies
The principal dependency of this project is `Python 2.7`, the code has not been tested with any other version of python. Beyond that the only other requirements are several python packages, most of which are fetched automatically by a tool called [`buildout`](https://pypi.python.org/pypi/zc.buildout/2.5.3).  However there are a couple of packages that buildout usually can't handle and those libraries, listed below, must be installed manually:
* [`GDAL`](http://www.gdal.org/)
* [`Fiona`]()
* [`Shapely`]() (requires [`GEOS`]() library)

#### Windows
There are number of of ways to get the above tools on Windows, but if you don't already have them installed I recommend using the compiled binaries/wheel files found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs) (links: [gdal](http://www.lfd.uci.edu/~gohlke/pythonlibs/#gdal), [fiona](http://www.lfd.uci.edu/~gohlke/pythonlibs/#fiona), [shapely](http://www.lfd.uci.edu/~gohlke/pythonlibs/#shapely)).  Several variants of the wheel files are offered so be sure to match the version and bit level of your python instance to the file that you select.  For instance to install gdal to 64-bit python 2.7 you would use download the `.whl` file below and use the following command:  
`pip install GDAL-2.0.3-cp27-cp27m-win_amd64.whl`


* [zc.buildout]()  
  to install this python package from the command line run: `pip install zc.buildout`
* [GDAL]() (and python bindings for GDAL)

#### Mac/Linux
Install gdal using your favorite package mananger like `homebrew` or `apt-get` and buildout should be able to fetch the python bindings for you automatically in a later step

#### Steps for Conversion
One the above dependecies are in place the hard part is over.  Follow the steps below to create the rlis.osm file that can be used in OSM editors
1. if you don't already have the python package zc.buildout install from the command line as such: `pip install zc.buildout`
2. from the home directory of this 



### Using the Data
**Note!!!** Upon successfully transforming the data do not add the tags that appear on the output to OpenStreetMap without first considering if they are a good fit for what is being mapped.  Much effort has been put into making this conversion as accurate as possible (with reliance on the [OSM Wiki](wiki.osm.org)), but streets and trails that have common attributes in RLIS may not always map to the same tags in OSM.  Use aerial imagery, the wiki, and any other license compliant resources that you have at your disposal to ensure that the attributes are accurate and in line with OSM convention before uploading them.

* notes on possible hosting of the output go here

* instructions on how to bring this large file into JOSM go here

* note about reporting bugs or new features
