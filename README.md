
# rlis2osm
![rlis2osm in josm](./docs/images/rlis2osm_in_josm_slim.png?raw=true)
<small>converted RLIS data loaded in the JOSM editor</small>

### Purpose
The majority of Oregon Metro's Regional Land Information System ([RLIS](http://www.oregonmetro.gov/rlis-live)) dataset, including the street, trail and bicycle centerline data that is used in this project, is now under the same license as OpenStreetMap ([OSM](osm.org)): the Open Database License ([ODbL](http://opendatacommons.org/licenses/odbl/)).  This means that edits to OSM that are derived from RLIS are fully compliant with OpenStreetMap's contribution terms.  Significant resources go into keeping RLIS accurate and up-to-date for the Portland metro region which makes it great resources for the improvement of OSM.

However, RLIS and OSM use a significantly different methodologies to classify attributes and RLIS is released in shapefile format which is not ideal for comparison to existing OSM data in an editing environment.  The code here converts the attributes, segmentation (splitting connected lines only when attributes differ, not at each intersection), and file format (.shp --> .osm) of RLIS into a state that mirrors OSM as closely as possible.

Because RLIS is updated quarterly this conversion needs to be executed often to keep pace with those improvements, but once the project dependencies are in place this tool reduces that task to launching a console script and waiting a few minutes for it to run.

### Converting the Data
As noted above the conversion itself should be a simple task, however if you're inexperienced in setting up a development environment or in working with the packages this project requires getting the dependencies in place can be a challenge.  If you're not interested in deploying the code, but would like to use the data to improve OSM, skip to the [Using the Data](#using-the-data) section below.

#### Dependencies
The principal dependency of this project is `Python 2.7`, the code has not been tested with any other version of python. Additionally a few python packages that are not a part of the standard library are needed, most of which are automatically fetched by a tool called [`buildout`](https://pypi.python.org/pypi/zc.buildout/2.5.3).  However there are a couple of packages that buildout usually can't retrieve and those libraries, listed below, should be installed manually:
* [`GDAL`](http://www.gdal.org/)
* [`Fiona`](https://github.com/Toblerity/Fiona)
* [`Shapely`](https://github.com/Toblerity/Shapely) (requires [`GEOS`](https://trac.osgeo.org/geos/) library)
* [`NumPy`](http://www.numpy.org/) (only required if shapely <= 1.5, but speeds up the execution time in all cases)

##### Windows
There are few different ways to get the above tools on Windows.  If you don't have them installed I recommend using the wheel files found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs) (links: [gdal](http://www.lfd.uci.edu/~gohlke/pythonlibs/#gdal), [fiona](http://www.lfd.uci.edu/~gohlke/pythonlibs/#fiona), [shapely](http://www.lfd.uci.edu/~gohlke/pythonlibs/#shapely), [numpy](http://www.lfd.uci.edu/~gohlke/pythonlibs/#numpy)).  Several variants of these files are offered so be sure to match the version and bit level of your python instance to the file that you select.  For instance to install gdal to 64-bit python 2.7 you would download the `.whl` file below and use the following command: 

```bash
pip install GDAL-2.0.3-cp27-cp27m-win_amd64.whl
```

##### Mac
Dependency retrieval on macOS is straightforward as `pip` can fetch macOS wheels for fiona and shapely that contain the other needed packages (gdal and numpy).  The following command should be all that is required:

```bash
pip install fiona shapely
```

##### Linux
Install the `libgdal-dev` and `libgeos-dev` libraries using your favorite package manager (for instance `apt-get` on Ubuntu) and buildout should be able to fetch the python bindings that you'll need.  The command should look something like this:

```bash
apt-get install libgdal-dev libgeos-dev
```

##### Virtaul Machine (Cross Platform)

If you don't want to deal with installing these dependencies on your operating system, using a virtual machine is another option.  [This sister project](https://github.com/grant-humphries/vagrant-ubuntu-gis) will spin up a virtual box and install all of the dependencies needed to run `rlis2osm` using [Vagrant](https://www.vagrantup.com/).  Feel free to open a ticket in that repo if you have any issues.

#### Conversion Instructions
With the dependencies in place follow the steps below to create the file `rlis.osm` which can be used in OSM editors:

1. If you don't yet have buildout installed do so with the following command:

    ```bash
    pip install zc.buildout
    ```
2. From the home directory of this repo enter the text below, it may take a few minutes for buildout to fetch all of the packages that the project requires:

    ```bash
    buildout
    ```
3. The previous step generates the console script that performs the conversion, to launch it from the home directory enter:

    ```bash
    ./bin/rlis2osm
    ```
    to obtain information on script usage and options use:
    
    ```bash
    ./bin/rlis2osm --help
    ```
<br>

The execution should take 10 minutes or so and the converted OSM file will be written to: `./data/rlis.osm` within the directory structure of your cloned repo (unless you specify a different write location).

### Troubleshooting

Below are resolutions to issues that have been encountered in deploying `rlis2osm`:

* When running `buildout` on Windows you may encounter the error below, resolve it by running buildout a second time:

    > WindowsError: [Error 5] Access is denied

* One of the packages that `rlis2osm` relies upon requires that the environment variable `GDAL_DATA` be set.  Depending on the operating system and gdal install this may be handled automatically, but if not this variable should be set to the folder that contains the file: `coordinate_axis.csv`.  This is often found under the `site-packages` tree of your python install.


### Using the Data
**Note!!!** Upon successfully transforming the data do not add the geometry and/or tags that appear in the output to OpenStreetMap without first considering if they are a good fit for what is being mapped.  Much effort has been put into making this conversion as accurate as possible (with reliance on the [OSM Wiki](wiki.osm.org)), but streets, trails and bicycle infrastructure that have common attributes in RLIS may not always map to the same tags in OSM.  Use aerial imagery, the wiki, and any other license compliant resources that you have at your disposal to ensure that the features being added or modified are accurate and in line with OSM convention before uploading them.

#### Hosted Data
I'm presently looking for hosting options for this data so that it can be downloaded without having to work with the code.  If you have a hosting solution drop me a line by opening a ticket in the issues section of this repo.  In the meantime if you would like a copy of the data and are unable to generate one, email me and I will send it your way.

#### Adding `rlis.osm` to JOSM
[JOSM](https://josm.openstreetmap.de/) (the Java OpenStreetMap editor) has the ability to load multiple .osm files at once, and bringing `rlis.osm` into JOSM is a great way to use it as an editing aid.  Because the generated file is fairly large at 100+ MB, you may need to allocate more than the default amount of memory to JOSM in order to load `rlis.osm` without crashing the application.  To do so launch JOSM from the terminal or create a shortcut that executes a launch command.  To run a `josm.jar` file from the terminal use:

```bash
java -Xmx1G -jar /path/to/your/josm/jar/file/josm-tested.jar
```

The `1G` in the snippet above is the amount of memory being allotted to JOSM (1 gigabyte in this case), you can adjust this, but it should be at least 200 MB to accommodate the file and the app's other data and functionality.  If using JOSM webstart (which automatically updates the app each time it is opened) you may need to modify its auto-created shortcut.  At last check webstart worked with `rlis.osm` out of the box on Mac, but on Windows the shortcut command had to be modified to something like the snippet below.  If you're unable to get things running you can read more about this [here](https://josm.openstreetmap.de/wiki/Download#VMselectiononWindowsx64).

```bat
"P:\ath\to\java\webstart\javaws.exe" ^
    -J-d64 ^
    -Xmx=2048m ^ 
    -localfile ^
    -J-Djnlp.application.href=https://josm.openstreetmap.de/download/josm.jnlp ^
    "P:\ath\to\cached\josm\app"
```

#### Requesting Features and Reporting Bugs
If there are features or functionality that you would like to see added to the project or you run into errors in the data or execution of the script feel free to open a ticket [here](https://github.com/grant-humphries/rlis2osm/issues).
