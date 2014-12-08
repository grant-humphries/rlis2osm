
### Purpose
The majority of Oregon Metro's 'Regional Land Information System' ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including the street and trail centerline data, is now under the same license as OpenStreetMap ([OSM](osm.org)), the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means deriving edits to OSM from RLIS is fully compliant with OpenStreetMap's contribution terms.  

However, RLIS and OSM use a vastly different methodologies to classify attributes and RLIS is released in shapefile format which is not ideal for comparison to existing OSM data in an editing environment.  The code in this repo converts the attributes, segmentation (output segments that are contiguous are only split where attributes differ, not at each intersection), and geodata type (outputs to .osm format) of RLIS data to mirror OSM data as closely as possible

An updated version of RLIs is released four times per year so it is neccessary to repeat this conversion often

**Note!!!** Do not add the tags that appear on the output data without first considering if they are a good fit for what is being mapped.  Much effort has been put into making this conversion as accurate as possible (with reliance on the [OSM Wiki](wiki.osm.org) to do so), but streets and trails that have the common attributes in RLIS may not always map to the same tags in OSM.  Use aerial imagery, the wiki, and any other license compliant resources that you have to ensure that the attributes are accurate and in line with OSM convention before uploading them.


### Dependencies
The following tools must be installed for the code in this repo to execute properly:

- [PostGreSQL](http://www.postgresql.org/download/)
	
    PostGres extensions:
    - [PostGIS](http://postgis.net/install/)
- [ogr2osm](https://github.com/pnorman/ogr2osm)
	
    Dependencies for GDAL:
    - [GDAL](http://www.gdal.org/)
    - Python bindings for gdal

I'm running this conversion on Windows and thus the shell scripts are batch files, for them to work on a Mac or Linux machine they would need to be rewritten in bash.

### Executing the Code
Once all of the dependencies are installed and running properly the latest verison of RLIS data can be downloaded here:
- [RLIS Streets](http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=556)
- [RLIS Trails](http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=2404)

From there the file paths for the street and trail data in the shell scripts need to be changed to point to what has been downloaded.  Also check all other files paths to ensure that they point to the version of the scripts and tools that need to be called that are on your machine.


#### Special Thanks
Thanks to Mele Sax-Barnett (@pdxmele) for initiating the automation  of this process (it took us weeks to do this conversion years ago as interns when approaching it manually and now takes less than 30 minutes!) and for writing the first draft of rlis_streets2osm.sql