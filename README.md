
### Purpose
The majority of Oregon Metro's 'Regional Land Information System' ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including its street and trail centerline data, is now under the same license as OpenStreetMap ([OSM](osm.org)), the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means that edits to OSM that are derived from RLIS are fully compliant with OpenStreetMap's contribution terms.  Significant resources go into keeping RLIS' street and trail data accurate and up-to-date for the Portland metro region which makes them great resources for the improvement of OSM.

However, RLIS and OSM use a significantly different methodologies to classify attributes and RLIS is released in shapefile format which is not ideal for comparison to existing OSM data in an editing environment.  The code here converts the attributes, segmentation (output segments that are contiguous are only split where attributes differ, not at each intersection), and geodata type (outputs to .osm format) of RLIS data to a state that mirrors OSM as closely as possible.

Because RLIS is updated and released quarterly the conversion needs to be executed often to have the most recent data available.  Once your system is properly configured this repo makes that process a matter of launching a single shell script.

### Dependencies
The following tools must be installed for rlis2osm to run properly:

* [PostGreSQL](http://www.postgresql.org/download/)  
  **PostGres extensions:**
    1. [PostGIS](http://postgis.net/install/)
* [ogr2osm](https://github.com/pnorman/ogr2osm)	 
  **Dependencies for ogr2osm:**
    1. [GDAL](http://www.gdal.org/)
    2. Python bindings for GDAL

The shell script to execute this workflow has been written in bash (linux, mac) and as a batchfile (windows) so if the dependencies are met the conversion should be possible on most major platforms.

### Executing the Conversion
Once the dependencies are installed and running properly the latest verison of RLIS data can be downloaded here:
* [RLIS Streets](http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=556)
* [RLIS Trails](http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=2404)

Within the shell script a few variables will need to be assigned to your local directories and environment settings.  These include the postgresql parameters (named `pg_user`, `pg_host`, `pg_dbase`), and the directores for rlis, this repo, the location where the osm data will be written and the directory holding ogr2osm.  Once these variables are sound launch `rlis2osm.sh` or `rlis2osm.bat` from the appropriate shell and the conversion will be carried out.

**Note!!!** Upon successfully transforming the data do not add the tags that appear on the output to OpenStreetMap without first considering if they are a good fit for what is being mapped.  Much effort has been put into making this conversion as accurate as possible (with reliance on the [OSM Wiki](wiki.osm.org)), but streets and trails that have common attributes in RLIS may not always map to the same tags in OSM.  Use aerial imagery, the wiki, and any other license compliant resources that you have at your disposal to ensure that the attributes are accurate and in line with OSM convention before uploading them.


#### Special Thanks
Thanks to Mele Sax-Barnett (@pdxmele) for initiating the automation of this process by writing the first draft of `rlis_streets2osm.sql`.  When approaching this manually a few years ago as interns it took us weeks to do this conversion and it now takes less than 30 minutes!