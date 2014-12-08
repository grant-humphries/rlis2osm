
### Purpose
The majority of Oregon Metro's 'Regional Land Information System' ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including the street and trail centerline data, is now under the same license as OpenStreetMap ([OSM](osm.org)), the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means deriving edits to OSM from RLIS is fully compliant with OpenStreetMap's contribution terms.  

However, RLIS and OSM use a vastly different methodologies to classify attributes and RLIS is released in shapefile format which is not ideal for comparison to existing OSM data in an editing environment.  The code in this repo converts the attributes, segmentation (output segments that are contiguous are only split where attributes differ, not at each intersection), and geodata type (outputs to .osm format) of RLIS data to mirror OSM data as closely as possible

An updated version of RLIs is released four times per year so it is neccessary to repeat this conversion often

Warning!!! Do add the tags on the output data without first considering if they are a good fit for what is being mapped.  The conversion 


### Dependencies
The following tools must be installed for the code in this repo to execute properly:

- [PostGreSQL](http://www.postgresql.org/download/)
	
    PostGres extensions:
    - [PostGIS](http://postgis.net/install/)
- [ogr2osm](https://github.com/pnorman/ogr2osm)
	
    Dependencies for GDAL:
    - [GDAL](http://www.gdal.org/)
    - python bindings for gdal

I'm running this conversion on Windows and thus the shell scripts are batch files, for them to work on a Mac or Linux machine they would need to be rewritten in bash.

### Executing the Code
Get the latest RLIS data here:
- [RLIS Streets]()
- [RLIS Trails]()

#### Special Thanks
Thanks to Mele Sax-Barnett (@pdxmele) for initiating the automation  of this process (it took us weeks to do this years ago when we did this manually as interns and now takes less than 30 minutes!) and writing the first draft of rlis_streets2osm.sql