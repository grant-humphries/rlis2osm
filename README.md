
## rlis2osm
![rlis2osm in josm](./images/rlis2osm_in_josm.png?raw=true "converted RLIS data in the JOSM editor")

### Purpose
The majority of Oregon Metro's 'Regional Land Information System' ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including its street and trail centerline data, is now under the same license as OpenStreetMap ([OSM](osm.org)), the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means that edits to OSM that are derived from RLIS are fully compliant with OpenStreetMap's contribution terms.  Significant resources go into keeping the RLIS street and trail data accurate and up-to-date for the Portland metro region which makes them great resources for the improvement of OSM.

However, RLIS and OSM use a significantly different methodologies to classify attributes and RLIS is released in shapefile format which is not ideal for comparison to existing OSM data in an editing environment.  The code here converts the attributes, segmentation (output segments that are contiguous are only split where attributes differ, not at each intersection), and geodata type (outputs to .osm format) of RLIS data to a state that mirrors OSM as closely as possible.

Because RLIS is updated and released quarterly the conversion needs to be executed often to have the most recent data available.  Once your system is properly configured this repo makes that process a matter of launching a single shell script.

### Executing the Conversion
This conversion can be carried out in a few 

#### Dependencies
The following tools must be installed for rlis2osm to run properly:

* Python 2.7 (not tested with any other version of python)
* [zc.buildout](https://pypi.python.org/pypi/zc.buildout/2.5.3)  
  to install this python package from the command line run: `pip install buildout`
* [GDAL](http://www.gdal.org/) (and python bindings for GDAL)
    * **Windows**: if you don't already have gdal installed I recommend using the binaries found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs/#gdal), be sure to match the version of bit level of your python instance to the wheel file you select.  For 64-bit python 2.7 for instance download `GDAL-2.0.3-cp27-cp27m-win_amd64.whl` and then run:
    ```
    pip install GDAL-2.0.3-cp27-cp27m-win_amd64.whl
    ```
    * **Mac/Linux** install gdal using your favorite package mananger like `homebrew` or `apt-get` and buildout should be able to fetch the python bindings for you automatically in a later step

The shell script to execute this workflow has been written in bash (linux, mac) and as a batchfile (windows) so if the dependencies are met the conversion should be possible on most major platforms.



### Using the Data
**Note!!!** Upon successfully transforming the data do not add the tags that appear on the output to OpenStreetMap without first considering if they are a good fit for what is being mapped.  Much effort has been put into making this conversion as accurate as possible (with reliance on the [OSM Wiki](wiki.osm.org)), but streets and trails that have common attributes in RLIS may not always map to the same tags in OSM.  Use aerial imagery, the wiki, and any other license compliant resources that you have at your disposal to ensure that the attributes are accurate and in line with OSM convention before uploading them.

* notes on possible hosting of the output go here

* instructions on how to bring this large file into JOSM go here
