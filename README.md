
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
The principal dependency of this project is `Python 2.7`, the code has not been tested with any other version of python. Beyond that the only other requirements are several python packages, most of which are automatically fetched by a tool called [`buildout`](https://pypi.python.org/pypi/zc.buildout/2.5.3).  However there are a couple of packages that buildout usually can't handle and those libraries, listed below, must be installed manually:
* [`GDAL`](http://www.gdal.org/)
* [`Fiona`](https://github.com/Toblerity/Fiona)
* [`Shapely`](https://github.com/Toblerity/Shapely) (requires [`GEOS`](https://trac.osgeo.org/geos/) library)

#### Windows
There are number of of ways to get the above tools on Windows, but if you don't already have them installed I recommend using the compiled binaries/wheel files found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs) (links: [gdal](http://www.lfd.uci.edu/~gohlke/pythonlibs/#gdal), [fiona](http://www.lfd.uci.edu/~gohlke/pythonlibs/#fiona), [shapely](http://www.lfd.uci.edu/~gohlke/pythonlibs/#shapely)).  Several variants of the wheel files are offered so be sure to match the version and bit level of your python instance to the file that you select.  For instance to install gdal to 64-bit python 2.7 you would use download the `.whl` file below and use the following command 
```
pip install GDAL-2.0.3-cp27-cp27m-win_amd64.whl
```

#### Mac/Linux
Install the gdal and geos libraries using your favorite package manager like `homebrew` or `apt-get` and buildout should be able to fetch the python bindings that you'll need automatically.  On mac, installing gdal with homebrew would look like this:
```
brew install gdal
```

#### Conversion Instructions
Once the above dependencies are the rest of the process should be straight-forward.  Follow the steps below to create the rlis.osm file that can be used in OSM editors
1. if you don't yet have buildout installed do so with the following command:
```
pip install zc.buildout
```
2. from the home directory of this repo enter the command below, it may take a few minutes for buildout to fetch all of the packages that the project requires:
```
buildout
```
3. the previous step generates the console script that performs the conversion, to launch it from the home directory enter:
```
./bin/rlis2osm
```
to obtain information on the script's options use:
```
./bin/rlis2osm --help
```
<br>

Once the script has been launched wait 10 minutes or so for the conversion to be carried out and the converted osm file will be written to: `./data/rlis.osm`

### Using the Data
**Note!!!** When using the converted `rlis.osm` Upon successfully transforming the data do not add the tags that appear on the output to OpenStreetMap without first considering if they are a good fit for what is being mapped.  Much effort has been put into making this conversion as accurate as possible (with reliance on the [OSM Wiki](wiki.osm.org)), but streets and trails that have common attributes in RLIS may not always map to the same tags in OSM.  Use aerial imagery, the wiki, and any other license compliant resources that you have at your disposal to ensure that the attributes are accurate and in line with OSM convention before uploading them.

#### Hosted Data
I'm presently looking for hosting options for this data so that one can simply download it without having to deal with the code.  If you have a hosting solution drop me a line by opening a ticket in the issues section of this repo.

#### Adding `rlis.osm` to JOSM
The Java OpenStreetMap Editor ([JOSM](https://josm.openstreetmap.de/)) has the ability to load multiple .osm files at once, and bringing `rlis.osm` into JOSM is a great way to use it as an editing aid.  Because the generated file is fairly large at 100+ MB you may need to allocate JOSM more than the default amount of memory to be able to load `rlis.osm` without crashig the application.  To do so you need to launch JOSM from the command line or create a shortcut that executes a similar command.  To launch a josm .jar file from the terminal use:
```
java -Xmx1G -jar /path/to/your/josm/jar/file/josm-tested.jar
```
the `1G` in the command above is the amount of memory being alotted to JOSM (1 gigabyte in this case), you can adjust this amount, but it should probably be at least 200 MB in this case.  If using JOSM webstart (which is handy because it automatically updates the app each time you open it) you may need to modify the shortcut that is automatically created for the app.  Webstart worked out of the box for me on Mac, but on Windows I had to modify the shortcut command to something like the code below.  If you're unable to get things running you can read more about this [here](https://josm.openstreetmap.de/wiki/Download#VMselectiononWindowsx64).
```
"P:\ath\to\java\webstart\javaws.exe" -J-d64 -Xmx=2048m \ 
    -localfile -J-Djnlp.application.href=https://josm.openstreetmap.de/download/josm.jnlp \
    "P:\ath\to\cached\josm\app"
```

#### Requesting Features and Reporting Bugs
If there are features or functionality that you would like to see added or if something looks off with the data feel free to open a ticket [here](https://github.com/grant-humphries/rlis2osm/issues).
