--RLIS trails to OSM attribute conversion, November 2012 by Grant Humphries for TriMet 

--client encoding is being changed from 'WIN1252' to 'UTF8', the when in the former state
--an error was being thrown when running this script with a batch file on Windows 7.  The
--command below and its complement at the end of the script can be removed if it causes
--problems in other environments
set client_encoding to 'UTF8';

--1) create temporary table on which to perform the attribute conversions
DROP TABLE if EXISTS osm_trails CASCADE;
CREATE TEMP TABLE osm_trails (
    id serial primary key,
    geom geometry,
    
    --These attributes map directly to osm and influence only one tag, their headings are osm keys
    name varchar(4000),
    systemname varchar(4000), --to be renamed RLIS:systemname
    alt_name varchar(4000),
    est_width text,
    wheelchair text, 
    mtb text,
    horse text,
    operator varchar(4000),

    --These attributes influence multiple tags and will eventually be dropped, their headings are rlis fields
    status text,
    trlsurface text,
    hike text,
    roadbike text,
    onstrbike text,

    --These attributes are derived from a single rlis field, but fields from which they're derived influence multiple tags and
    --thus are kept in a separate column, the headings here are osm keys
    access text,
    fee text,
    abandoned text,
    surface text,

    --These attributes are derived from multiple rlis fields, the logic to determine the values within is below
    --The heading to these columns are osm keys
    highway text,
    proposed text,
    cnstrctn text,  --to be renamed construction
    hwy_abndnd text, --to be renamed highway:abandoned
    foot text,
    bicycle text
);


--2) POPULATE osm_sts from rlis_trails
INSERT INTO osm_trails (geom, name, systemname, alt_name, est_width, wheelchair, mtb, horse, operator, 
  status, trlsurface, hike, roadbike, onstrbike)
    (
    SELECT rs.geom, rs.trailname, rs.systemname, rs.sharedname, rs.width, rs.accessible, rs.mtnbike,
      rs.equestrian, rs.agencyname, rs.status, rs.trlsurface, rs.hike, rs.roadbike, rs.onstrbike
    FROM   rlis_trails rs
    );

--3) Remove water and conceptual trails
DELETE FROM osm_trails where status = 'Conceptual';
DELETE FROM osm_trails where trlsurface = 'Water';

--4) Remove Abbreviations and unwanted characters and descriptors from name, systemname, alt_name, and operator fields

--Proper case basic name
--Below function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php

CREATE OR REPLACE FUNCTION "format_titlecase" (
  "v_inputstring" varchar
)
RETURNS varchar AS
$body$


--select * from Format_TitleCase('MR DOG BREATH');
--select * from Format_TitleCase('each word, mcclure of this string:shall be transformed');
--select * from Format_TitleCase(' EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
--select * from Format_TitleCase('mcclure and others');
--select * from Format_TitleCase('J & B ART');
--select * from Format_TitleCase('J&B ART');
--select * from Format_TitleCase('J&B ART J & B ART this''s art''s house''s problem''s 0''shay o''should work''s EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');


DECLARE
   v_Index  INTEGER;
   v_Char  CHAR(1);
   v_OutputString  VARCHAR(4000);
   SWV_InputString VARCHAR(4000);

BEGIN
   SWV_InputString := v_InputString;
   SWV_InputString := LTRIM(RTRIM(SWV_InputString)); --cures problem where string starts with blank space
   v_OutputString := LOWER(SWV_InputString);
   v_Index := 1;
   v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,1,1)) from 1 for 1); -- replaces 1st char of Output with uppercase of 1st char from Input
   WHILE v_Index <= LENGTH(SWV_InputString) LOOP
      v_Char := SUBSTR(SWV_InputString,v_Index,1); -- gets loop's working character
      IF v_Char IN('m','M','',';',':','!','?',',','.','_','-','/','&','''','(',CHR(9)) then
         --END4
         IF v_Index+1 <= LENGTH(SWV_InputString) then
            IF v_Char = '''' AND UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) <> 'S' AND SUBSTR(SWV_InputString,v_Index+2,1) <> REPEAT(' ',1) then  -- if the working char is an apost and the letter after that is not S
               v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
            ELSE 
               IF v_Char = '&' then    -- if the working char is an &
                  IF(SUBSTR(SWV_InputString,v_Index+1,1)) = ' ' then
                     v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
                  ELSE
                     v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
                  END IF;
               ELSE
                  IF UPPER(v_Char) != 'M' AND (SUBSTR(SWV_InputString,v_Index+1,1) <> REPEAT(' ',1) AND SUBSTR(SWV_InputString,v_Index+2,1) <> REPEAT(' ',1)) then
                     v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
                  END IF;
               END IF;
            END IF;

                    -- special case for handling "Mc" as in McDonald
            IF UPPER(v_Char) = 'M' AND UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) = 'C' then
               v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index,1)) from v_Index for 1);
                            --MAKES THE C LOWER CASE.
               v_OutputString := OVERLAY(v_OutputString placing LOWER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
                            -- makes the letter after the C UPPER case
               v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
                            --WE TOOK CARE OF THE CHAR AFTER THE C (we handled 2 letters instead of only 1 as usual), SO WE NEED TO ADVANCE.
               v_Index := v_Index+1;
            END IF;
         END IF;
      END IF; --END3

      v_Index := v_Index+1;
   END LOOP; --END2

   RETURN coalesce(v_OutputString,'');
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;



--back to Mele's code
--a) Remove abbreviations from "name"
--Convert to camel case
UPDATE osm_trails set name = format_titlecase(name);

--Add index to speed performance
DROP INDEX IF EXISTS name_ix CASCADE;
CREATE INDEX name_ix ON osm_trails USING BTREE (name);

--Removes periods and extra spaces
UPDATE osm_trails set name = replace(name, '.', '');

--Various grammar fixes *not* related to abbreviations
UPDATE osm_trails set name = replace(name, ' And ', ' and ');
UPDATE osm_trails set name = replace(name, ' To ', ' to ');
UPDATE osm_trails set name = replace(name, ' With ', ' with ');
UPDATE osm_trails set name = replace(name, ' Of ', ' of ');
UPDATE osm_trails set name = replace(name, ' On ', ' on ');
UPDATE osm_trails set name = replace(name, ' The ', ' the ');
UPDATE osm_trails set name = replace(name, ' At ', ' at ');
UPDATE osm_trails set name = replace(name, ' - Connector', '') where (name LIKE '%Connector%Connector%');

--Street prefixes
UPDATE osm_trails set name = replace(name, 'N ', 'North ');
UPDATE osm_trails set name = replace(name, 'Ne ', 'Northeast ');
UPDATE osm_trails set name = replace(name, 'Nw ', 'Northwest ');
UPDATE osm_trails set name = replace(name, 'Se ', 'Southeast ');
UPDATE osm_trails set name = replace(name, 'Sw ', 'Southwest ');

--Street sufixes that are comprised of letter combination that *don't* appear in other words
UPDATE osm_trails set name = replace(name, 'Rd', 'Road');
UPDATE osm_trails set name = replace(name, 'Ct', 'Court');
UPDATE osm_trails set name = replace(name, 'Ln', 'Lane');
UPDATE osm_trails set name = replace(name, 'Lp', 'Loop');
UPDATE osm_trails set name = replace(name, 'Blvd', 'Boulevard');
UPDATE osm_trails set name = replace(name, 'Pkwy', 'Parkway');
UPDATE osm_trails set name = replace(name, 'Hwy', 'Highway');

--Saint at the beginning of the field, this must be in front the "street" expansion code
UPDATE osm_trails set name = replace(name, 'St ', 'Saint ') where left(name, 2) = 'St';

--Street sufixes that are comprised of letter combination that appear in other words
--The first line of code overwrites only abbreviations that appear at the end of a field
--the second line contains a space after the abbreviation so words beginning with these letters won't be modified
UPDATE osm_trails set name = replace(name, 'Ave', 'Avenue') where right(name, 3) = 'Ave';
UPDATE osm_trails set name = replace(name, 'Ave ', 'Avenue ');
UPDATE osm_trails set name = replace(name, 'St', 'Street') where right(name, 2) = 'St';
UPDATE osm_trails set name = replace(name, 'St ', 'Street ');
UPDATE osm_trails set name = replace(name, 'Pl', 'Place') where right(name, 2) = 'Pl';
UPDATE osm_trails set name = replace(name, 'Pl ', 'Place ');
UPDATE osm_trails set name = replace(name, 'Dr', 'Drive') where right(name, 2) = 'Dr';
UPDATE osm_trails set name = replace(name, 'Dr ', 'Drive ');
UPDATE osm_trails set name = replace(name, 'Ter', 'Terrace') where right(name, 3) = 'Ter';
UPDATE osm_trails set name = replace(name, 'Ter ', 'Terrace ');
UPDATE osm_trails set name = replace(name, 'Terr', 'Terrace') where right(name, 4) = 'Terr';
UPDATE osm_trails set name = replace(name, 'Terr ', 'Terrace ');
UPDATE osm_trails set name = replace(name, 'Wy', 'Way') where right(name, 2) = 'Wy';
UPDATE osm_trails set name = replace(name, 'Wy ', 'Way ');

--Other abbreviation extensions
UPDATE osm_trails set name = replace(name, 'Ped ', 'Pedestrian ');
UPDATE osm_trails set name = replace(name, 'Tc', 'Transit Center');
UPDATE osm_trails set name = replace(name, 'Assn', 'Association');
UPDATE osm_trails set name = replace(name, 'Hmwrs', 'Homeowners');
UPDATE osm_trails set name = replace(name, 'Mt ', 'Mount ');
UPDATE osm_trails set name = replace(name, 'Jr ', 'Junior ');

--Special cases
UPDATE osm_trails set name = replace(name, ' Hoa', ' Homeowners Association');
UPDATE osm_trails set name = replace(name, 'Bpa ', 'Bonneville Power Administration ');
UPDATE osm_trails set name = replace(name, 'Bes ', 'Bureau of Environmental Services ');
UPDATE osm_trails set name = replace(name, 'Fulton Cc', 'Fulton Community Center');
UPDATE osm_trails set name = replace(name, 'HM', 'Howard M.');

--Unknown abbreviations switched back to caps
UPDATE osm_trails set name = replace(name, 'Tbbv', 'TBBV');

--MAX is most common name, most folks don't know Metropolitan Area eXpress
UPDATE osm_trails set name = replace(name, 'Max ', 'MAX ');

--b) Remove abbreviations from "alt_name"
--Removes extra spaces
UPDATE osm_trails set alt_name = replace(alt_name, '  ', ' ');

DROP INDEX IF EXISTS alt_name_ix CASCADE;
CREATE INDEX alt_name_ix ON osm_trails USING BTREE (alt_name);

--grammar fixes
UPDATE osm_trails set alt_name = replace(alt_name, ' To ', ' to ');
UPDATE osm_trails set alt_name = replace(alt_name, ' The ', ' the ');
UPDATE osm_trails set alt_name = replace(alt_name, ' And ', ' and ');

--abbreviation expansions
UPDATE osm_trails set alt_name = replace(alt_name, 'Mt ', 'Mount ');
UPDATE osm_trails set alt_name = replace(alt_name, 'SW ', 'Southwest ');
UPDATE osm_trails set alt_name = replace(alt_name, 'Ave ', 'Avenue ');


--c) Remove abbreviations from "systemname"
--Convert to Camel Case
UPDATE osm_trails set systemname = format_titlecase(systemname);

DROP INDEX IF EXISTS systemname_ix CASCADE;
CREATE INDEX systemname_ix ON osm_trails USING BTREE (systemname);

--Removes periods and extra spaces
UPDATE osm_trails set systemname = replace(systemname, '.', '');
UPDATE osm_trails set systemname = replace(systemname, '  ', ' ');

--grammar fixes
UPDATE osm_trails set systemname = replace(systemname, ' Of ', ' of ');
UPDATE osm_trails set systemname = replace(systemname, ' To ', ' to ');
UPDATE osm_trails set systemname = replace(systemname, ' On ', ' on ');
UPDATE osm_trails set systemname = replace(systemname, ' The ', ' the ');
UPDATE osm_trails set systemname = replace(systemname, ' At ', ' at ');
UPDATE osm_trails set systemname = replace(systemname, ' And ', ' and ');

--Street prefixes
UPDATE osm_trails set systemname = replace(systemname, 'Nw ', 'Northwest ');
UPDATE osm_trails set systemname = replace(systemname, 'Se ', 'Southeast ');
UPDATE osm_trails set systemname = replace(systemname, 'Sw ', 'Southwest ');

--Street sufixes that are comprised of letter combination that *don't* appear in other words
UPDATE osm_trails set systemname = replace(systemname, 'Rd', 'Road');
UPDATE osm_trails set systemname = replace(systemname, 'Hwy', 'Highway');

--Street sufixes that are comprised of letter combination that appear in other words
UPDATE osm_trails set systemname = replace(systemname, 'Ave', 'Avenue') where right(systemname, 3) = 'Ave';
UPDATE osm_trails set systemname = replace(systemname, 'Ave ', 'Avenue ');

--Other abbreviation extensions
UPDATE osm_trails set systemname = replace(systemname, 'Mt ', 'Mount ');
UPDATE osm_trails set systemname = replace(systemname, 'St ', 'Saint ');
UPDATE osm_trails set systemname = replace(systemname, 'Ped ', 'Pedestrian ');
UPDATE osm_trails set systemname = replace(systemname, 'Assn', 'Association');
UPDATE osm_trails set systemname = replace(systemname, 'Hmwrs', 'Homeowners');
UPDATE osm_trails set systemname = replace(systemname, ' Hoa', ' Homeowners Association');
UPDATE osm_trails set systemname = replace(systemname, ' Ms', ' Middle School');
UPDATE osm_trails set systemname = replace(systemname, 'Es ', 'Elementary School ');
UPDATE osm_trails set systemname = replace(systemname, 'Lds', 'Latter Day Saints');
UPDATE osm_trails set systemname = replace(systemname, ' No ', ' #');
UPDATE osm_trails set systemname = replace(systemname, 'Inc ', 'Incorporated ');

--Special cases
UPDATE osm_trails set systemname = replace(systemname, 'AM', 'Archibald M.');
UPDATE osm_trails set systemname = replace(systemname, 'HM', 'Howard M.');
UPDATE osm_trails set systemname = replace(systemname, 'Uj Hamby', 'Ulin J. Hamby');
UPDATE osm_trails set systemname = replace(systemname, 'Pkw', 'Peterkort Woods');
UPDATE osm_trails set systemname = replace(systemname, 'Thprd', 'Tualatin Hills Park & Recreation District');
UPDATE osm_trails set systemname = replace(systemname, 'Tvwd', 'Tualatin Valley Water District');
UPDATE osm_trails set systemname = replace(systemname, 'Pcc', 'Portland Community College');
UPDATE osm_trails set systemname = replace(systemname, 'Psu', 'Portland State University');
UPDATE osm_trails set systemname = replace(systemname, 'Wsu', 'Washington State University');

--Typo fixes
UPDATE osm_trails set systemname = replace(systemname, 'Ccccccc', '');
UPDATE osm_trails set systemname = replace(systemname, 'Chiefain', 'Chieftain');
UPDATE osm_trails set systemname = replace(systemname, 'Esl ', 'Elementary School ');
UPDATE osm_trails set systemname = replace(systemname, 'Tanasbource', 'Tanasbourne');
UPDATE osm_trails set systemname = replace(systemname, 'Wilamette', 'Willamette');
UPDATE osm_trails set systemname = replace(systemname, 'Southwest Pedestrian Walkway', 'Southwest Pedestrian Walkways');


--Unknown abbreviations switched back to caps
UPDATE osm_trails set systemname = replace(systemname, 'Pbh', 'PBH');

--MAX is most common name, most folks don't know Metropolitan Area eXpress
UPDATE osm_trails set systemname = replace(systemname, 'Max ', 'MAX ');

--Delete value in "systemname" for trails that where it duplictates the value in "name" or "alt_name"
UPDATE osm_trails set systemname = '' 
    where (UPPER(systemname) = UPPER(name) OR UPPER(systemname) = UPPER(alt_name));


--d) Remove abbreviations from "operator"

--These entries don't actually explain who the operator is, thus their removal
UPDATE osm_trails set operator = '' 
    where operator = 'Home Owner Association' OR operator = 'Unknown';

--A few minor fixes, everything is already expanded, cameled, etc. for the most part
UPDATE osm_trails set operator = replace(operator, 'US', 'United States');
UPDATE osm_trails set operator = replace(operator, 'COUNTY', 'County');

--5) Convert Attributes from RLIS to OSM nomenclature
--a) Staight-forward conversions for populated columns

--est_width
UPDATE osm_trails set est_width = '1.0' where est_width = '1-5';
UPDATE osm_trails set est_width = '2.5' where est_width = '6-9';
UPDATE osm_trails set est_width = '2.5' where est_width = '5-10';
UPDATE osm_trails set est_width = '3.0' where est_width = '10';
UPDATE osm_trails set est_width = '3.5' where est_width = '10-14';
UPDATE osm_trails set est_width = '4.5' where est_width = '15+';
UPDATE osm_trails set est_width = '' where est_width = 'Unknown';

--wheelchair=*
UPDATE osm_trails set wheelchair =  'yes' where wheelchair = 'Accessible';
UPDATE osm_trails set wheelchair =  'no' where wheelchair = 'Not Accessible';
UPDATE osm_trails set wheelchair =  '' where wheelchair != 'Accessible' AND wheelchair != 'Not Accessible';

--mtb=*
UPDATE osm_trails set mtb = 'yes' where mtb = 'Yes';
UPDATE osm_trails set mtb = 'no' where mtb = 'No';
UPDATE osm_trails set mtb = '' where mtb != 'Yes' AND mtb != 'No';

--horse=*
UPDATE osm_trails set horse = 'yes' where horse = 'Yes';
UPDATE osm_trails set horse = 'no' where horse = 'No';
UPDATE osm_trails set horse = '' where horse != 'Yes' AND horse != 'No';

--b) Staight-forward conversions for empty columns

--Add indices to improve perfromance
DROP INDEX IF EXISTS status_ix CASCADE;
CREATE INDEX status_ix ON osm_trails USING BTREE (status);

DROP INDEX IF EXISTS trlsurface_ix CASCADE;
CREATE INDEX trlsurface_ix ON osm_trails USING BTREE (trlsurface);

--access=*
UPDATE osm_trails set access = 'license' where status = 'Restricted';
UPDATE osm_trails set access = 'unknown' where status = 'Unknown';
UPDATE osm_trails set access = 'private' where status = 'Restricted_Private';

--fee=*
UPDATE osm_trails set fee = 'yes' where status = 'Open_Fee';

--abandoned=*
--Need to append and "abandoned:" prefix on the highway tags of trails that have this tag
UPDATE osm_trails set abandoned = 'yes' where status = 'Decommissioned';

-- surface=*
UPDATE osm_trails set surface = 'ground' where trlsurface = 'Native Material';
UPDATE osm_trails set surface = 'woodchip' where trlsurface = 'Chunk Wood';
--Comparison of value "Hard Surface" is done in upper case because there are inconsistencies 
--in capitalization of this phrase
UPDATE osm_trails set surface = 'paved' where UPPER(trlsurface) = UPPER('Hard Surface');
UPDATE osm_trails set surface = 'wood' where trlsurface = 'Decking';
UPDATE osm_trails set surface = 'pebblestone' where trlsurface = 'Imported Material';

--c) Straight forward conversions on empty columns that will be over written in some places based on other attributes

DROP INDEX IF EXISTS hike_ix CASCADE;
CREATE INDEX hike_ix ON osm_trails USING BTREE (hike);

DROP INDEX IF EXISTS roadbike_ix CASCADE;
CREATE INDEX roadbike_ix ON osm_trails USING BTREE (roadbike);

--foot=*
UPDATE osm_trails set foot = 'no' where hike = 'No';
 
--bicycle=*
UPDATE osm_trails set bicycle = 'yes' where roadbike = 'Yes';
UPDATE osm_trails set bicycle = 'no' where roadbike = 'No';

--d) Complex conversions

--Add indices to improve performance
DROP INDEX IF EXISTS horse_ix CASCADE;
CREATE INDEX horse_ix ON osm_trails USING BTREE (horse);

DROP INDEX IF EXISTS onstrbike_ix CASCADE;
CREATE INDEX onstrbike_ix ON osm_trails USING BTREE (onstrbike);

DROP INDEX IF EXISTS est_width_ix CASCADE;
CREATE INDEX est_width_ix ON osm_trails USING BTREE (est_width);

--highway=*
--First set all entries to highway=footway
UPDATE osm_trails set highway = 'footway';

--Multi-Use Paths (MUPs)
UPDATE osm_trails set highway = 'path', bicycle = 'designated', foot = 'designated'
   where roadbike = 'Yes' AND hike = 'Yes' AND est_width != '1.0' AND (onstrbike = 'Yes' OR onstrbike = 'No')
   AND (UPPER(trlsurface) = UPPER('Hard Surface') OR trlsurface = 'Decking');

--Bike only paths
UPDATE osm_trails set highway = 'cycleway', bicycle = ''
   where roadbike = 'Yes' AND onstrbike = 'Yes' AND est_width != '1.0'
   AND (UPPER(trlsurface) = UPPER('Hard Surface') OR trlsurface = 'Decking') AND hike = 'No';

--Hiking Trails
UPDATE osm_trails set highway = 'path', foot = 'designated'
   where hike = 'Yes' AND roadbike = 'No' AND UPPER(trlsurface) != UPPER('Hard Surface') AND horse != 'yes';

--Horseback riding trails
UPDATE osm_trails set highway = 'bridleway'
   where horse = 'yes' AND roadbike = 'No' AND UPPER(trlsurface) != UPPER('Hard Surface');
UPDATE osm_trails set foot = 'yes' where highway = 'bridleway' AND hike = 'Yes';

--Stairs (this is stored on trlsurface for some reason)
UPDATE osm_trails set highway = 'steps', bicycle = '', foot = '' 
   where trlsurface = 'Stairs';

--Move value out of highway column and into another colunm for special cases like construction, proposed and abandoned features
UPDATE osm_trails set hwy_abndnd = highway, highway = '' where abandoned = 'yes';
UPDATE osm_trails set cnstrctn = highway, highway = 'construction' where status = 'Under construction';
UPDATE osm_trails set proposed = highway, highway = 'proposed' where status = 'Planned';

--A footway with a foot=no tag doesn't make sense, I found that this was occuring on trails that require a fee to access
UPDATE osm_trails set foot = 'license', access = 'no' where highway = 'footway' AND foot = 'no';


--6) Merge contiguous segment that have the same values for all attributes, this requires the creation of a new table as
--far as I can tell
DROP TABLE IF EXISTS osm_trails_final CASCADE;
CREATE TABLE osm_trails_final WITH OIDS AS
    --st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or multi-polygons) into its
    --individual component parts and creates and entry in the table for each of those parts
    SELECT (ST_Dump(geom)).geom AS geom, name, systemname, alt_name, est_width, wheelchair, mtb,
        horse, operator, access, fee, abandoned, surface, highway, proposed, cnstrctn, hwy_abndnd, 
        foot, bicycle
    --st_union merges all the grouped features into a single geometry collection and st_linemerege makes 
    --connected segments into single unified lines where possible
    FROM (SELECT ST_LineMerge(ST_Union(geom)) AS geom, name, systemname, alt_name, est_width,
              wheelchair, mtb, horse, operator, access, fee, abandoned, surface, highway, proposed, 
              cnstrctn, hwy_abndnd, foot, bicycle 
          FROM osm_trails
          GROUP BY name, systemname, alt_name, est_width, wheelchair, mtb, horse, operator, 
              access, fee, abandoned, surface, highway, proposed, cnstrctn, hwy_abndnd, foot, 
              bicycle) as unioned_trails;

--Get rid of the temporary table in which all of the translations were made
DROP TABLE IF EXISTS osm_trails CASCADE;


/**
PGSQL2SHP INSTRUCTIONS
In command prompt go to C:\Program Files\PostgreSQL\9.2\bin (or wherever your pgsql2shp is located, but its best to just added to your
path to bypass this step)

Enter the following to export the shapefile to your local system (change directory as needed), or use QGIS instead to connect to db and use “save as”:
pgsql2shp -k -u username -P password -f export\file\path.shp db_name schema.table_name

the 'k' parameter is to keep the case of the postgres column headers, they will be converted to upper case w/o this

Then run ogr2osm to convert from shapefile to .osm use the following command in the OSGeo4W window, or anywhere where GDAL is set up 
python bindings (which can be tough to do on Windows w/o OSGeo4W):
python ogr2osm.py -f -e 2913 -o P:\TEMP\rlis_trails.osm -t rlis_trails_trans.py P:\TEMP\rlis2osm_trails.shp
**/

--return client encoding to default setting, change is specific to the windows environment 
--that this script is being run in using a batch file with the command prompt, the command
--below and its complement at the beginning of the script can be removed if it causes
--problems in other environments
reset client_encoding;