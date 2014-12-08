
## Purpose
The majority of Oregon Metro's 'Regional Land Information System' ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including the street and trail centerline data, is now under the same license as OpenStreetMap ([OSM](osm.org)), the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means deriving edits to OSM from RLIS is fully compliant with OpenStreetMap's contribution terms.  However, 

An updated version of RLIs is released four times per year so it is neccessary to repeat this conversion often



## Dependencies
The following tools must be installed for the code in this repo to execute properly:

- [PostGreSQL](http://www.postgresql.org/download/)
	
    PostGres extensions:
    - [PostGIS](http://postgis.net/install/)
- [ogr2osm](https://github.com/pnorman/ogr2osm)
	
    Dependencies for GDAL:
    - [GDAL](http://www.gdal.org/)
    - python bindings for gdal

I'm executing this conversion on Windows so the shell scripts will need to be rewritten in bash to work on a Mac or Linux machine.

## Executing the Code
Get the latest RLIS data here:
- [RLIS Streets]()
- [RLIS Trails]()

### Special Thanks
Thanks to Mele Sax-Barnett (@pdxmele) for initiating the automation  of this process (it took us weeks to do this years ago when we did this manually as interns and now takes less than 30 minutes!) and writing the first draft of rlis_streets2osm.sql