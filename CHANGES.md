## Changes

#### 1.0.0 (unreleased) 
* Eliminate Postgres/PostGIS dependency and use python for all aspects of the conversion.  Modules ported from SQL:
    * street name abbreviation
    * attribute conversion
    * geometry concatenation
* Combine streets and trails into a single `.osm` file
* Add bike infrastructure tags to streets
* Fetch RLIS data from Metro's servers
    * Check if package is being run in TriMet environment and if data is already present there bypass the download and uses the existing files
* Add logging
* Create console script (including command line options) to launch converter

#### 0.2.0 (2015-05-09)
* Refactor SQL to use fewer queries
* Merge connected line segments that have identical tags
* Create bash version of the master shell script

#### 0.1.0 (2014-11-21)
* Load RLIS shapefiles into a PostreSQL/PostGIS database
* Convert attributes to OSM tags via SQL
* Export transformed data back to `.shp`
* Use `ogr2osm` project to convert street and trail shapefiles to OpenStreetMap geodata format
* Script the execution of sub-tasks in a batchfile (Windows `cmd`)


h/t to Mele Sax-Barnett and Frank Purcell for writing the earliest (pre GitHub) version of the SQL scripts

