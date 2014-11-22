--RLIS streets to OSM attribute conversion, 2012-2013 by Melelani Sax-Barnett + Grant Humphries for TriMet
--load the rlis streets shapefile into PostGIS with the following command: 
--shp2pgsql -I -s 2913 \\gisstore\gis\Rlis\STREETS\streets.shp rlis_streets | psql -U postgres -d rlis_streets

--client encoding is being changed from 'WIN1252' to 'UTF8', the when in the former state
--an error was being thrown when running this script with a batch file on Windows 7.  The
--command below and its complement at the end of the script can be removed if it causes
--problems in other environments
set client_encoding to 'UTF8';

--1) CREATE a new table
DROP TABLE if EXISTS osm_sts cascade;
CREATE TEMP TABLE osm_sts (
    id serial primary key,
    geom geometry,
    name text,
    highway text,
    oneway text,
    access text,
    service text,
    surface text,
    pc_left text, --to be renamed addr:postcode:left
    pc_right text, --to be renamed addr:postcode:right
    description text,
    
    --these fields are for intermediate steps and will be dropped
    prefix text,
    streetname varchar(4000),
    st_name_proper varchar(4000),
    st_name_abb_fix text,
    ftype text,
    direction text,
    st_class bigint,
    lcounty text,
    rcounty text
);


--2) POPULATE osm_sts from rlis rlis_streets
INSERT INTO osm_sts (geom, prefix, streetname, ftype, direction, st_class, pc_left, pc_right, lcounty, rcounty)
    (SELECT rs.geom, rs.prefix, rs.streetname, rs.ftype, rs.direction, rs.type, rs.leftzip, rs.rightzip, rs.lcounty, rs.rcounty
     FROM rlis_streets rs);


--3) NAME CONVERSIONS
--a) Prefix
UPDATE osm_sts set prefix = 'Northwest'
   WHERE prefix = 'NW';
UPDATE osm_sts set prefix = 'Southwest'
   WHERE prefix = 'SW';
UPDATE osm_sts set prefix = 'Southeast'
   WHERE prefix = 'SE';
UPDATE osm_sts set prefix = 'Northeast'
   WHERE prefix = 'NE';
UPDATE osm_sts set prefix = 'North'
   WHERE prefix = 'N';
UPDATE osm_sts set prefix = 'East'
   WHERE prefix = 'E';
UPDATE osm_sts set prefix = 'South'
   WHERE prefix = 'S';
UPDATE osm_sts set prefix = 'West'
   WHERE prefix = 'W';

--b) Proper case basic name
--Below function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php
CREATE OR REPLACE FUNCTION "format_titlecase" (
  "v_inputstring" varchar
)
RETURNS varchar AS
$body$

/*
select * from Format_TitleCase('MR DOG BREATH');
select * from Format_TitleCase('each word, mcclure of this string:shall be transformed');
select * from Format_TitleCase(' EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
select * from Format_TitleCase('mcclure and others');
select * from Format_TitleCase('J & B ART');
select * from Format_TitleCase('J&B ART');
select * from Format_TitleCase('J&B ART J & B ART this''s art''s house''s problem''s 0''shay o''should work''s EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
*/

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

--mine
UPDATE osm_sts set st_name_proper = format_titlecase(streetname);

--c) Deal with abbreviations/common fixes in st_name_proper
UPDATE osm_sts set st_name_abb_fix = st_name_proper;

DROP INDEX IF EXISTS st_name_abb_fix_ix CASCADE;
CREATE INDEX st_name_abb_fix_ix ON osm_sts USING BTREE (st_name_abb_fix);

UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Hwy', 'Highway');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Fwy', 'Freeway');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Pkwy', 'Parkway');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Blvd', 'Boulevard');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Co Rd', 'County Road');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Rd', 'Road');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Brg', 'Bridge');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Pl ', 'Place ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Pl-', 'Place-');
--Pl at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Place' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 2) = 'Pl';

--Ave
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ave-', 'Avenue-');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ave ', 'Avenue ');
--Ave at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Avenue' from (char_length(st_name_abb_fix) - 2) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 3) = 'Ave';
--Av at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Avenue' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 2) = 'Av';

--St
--St at beginning of field (Saint)
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Saint ' from 1 for 3) 
    WHERE left(st_name_abb_fix, 3) = 'St ';
--Mount Saint...
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Mt St ', 'Mount Saint ');
--Old Saint...
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Old St ', 'Old Saint ');
--"St."
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'St.', 'Saint');
--"St-"
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'St-', 'Street-');
--St at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Street' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 2) = 'St';
--remaining cases
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'St ', 'Street ');

--Dr
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Dr-', 'Drive-');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Dr ', 'Drive ');
--Dr at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Drive' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 2) = 'Dr';

UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ct ', 'Court ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ct-', 'Court-');
--Ct at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Court' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 2) = 'Ct';

UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Jr ', 'Junior ');
--Jr at end of field
UPDATE osm_sts set st_name_abb_fix = overlay(st_name_abb_fix placing 'Junior' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
    WHERE right(st_name_abb_fix, 2) = 'Jr';

UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Tc', 'Transit Center');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Us ', 'United States ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Med ', 'Medical ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Hosp ', 'Hospital ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Hosp/', 'Hospital/');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Mt ', 'Mount ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Cc', 'Community College');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Nfd ', 'National Forest Development ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Mtn', 'Mountain');

--super special cases
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Bpa', 'Bonneville Power Administration');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Cesar e Chavez', 'Cesar E Chavez');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'ArMcO', 'ARMCO');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of n Holladay', 'North Holladay');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of Se Madison', 'Southeast Madison');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of Se Marion', 'Southeast Marion');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, '99e', '99E');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, '99w', '99W');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Jq ', 'JQ ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, ' o ', ' O ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, ' w ', ' W ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, ' v ', ' V ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, ' s ', ' S ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Obrien', 'O’Brien');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Oday', 'O’Day');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Oneal', 'O’Neal');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Oneill', 'O’Neill');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Oneil', 'O’Neil');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Pcc ', 'Portland Community College ');
UPDATE osm_sts set st_name_abb_fix = replace(st_name_abb_fix, 'Portland Traction Co', 'Portland Traction Company');

--d) ftype (street type)
UPDATE osm_sts set ftype = 'Alley' WHERE ftype = 'ALY';
UPDATE osm_sts set ftype = 'Avenue' WHERE ftype = 'AVE';
UPDATE osm_sts set ftype = 'Boulevard' WHERE ftype = 'BLVD';
UPDATE osm_sts set ftype = 'Bridge' WHERE ftype = 'BRG';
UPDATE osm_sts set ftype = 'Circle' WHERE ftype = 'CIR';
UPDATE osm_sts set ftype = 'Corridor' WHERE ftype = 'CORR';
UPDATE osm_sts set ftype = 'Crescent' WHERE ftype = 'CRST';
UPDATE osm_sts set ftype = 'Court' WHERE ftype = 'CT';
UPDATE osm_sts set ftype = 'Drive' WHERE ftype = 'DR';
UPDATE osm_sts set ftype = 'Expressway' WHERE ftype = 'EXPY';
UPDATE osm_sts set ftype = 'Frontage' WHERE ftype = 'FRTG';
UPDATE osm_sts set ftype = 'Freeway' WHERE ftype = 'FWY';
UPDATE osm_sts set ftype = 'Highway' WHERE ftype = 'HWY';
UPDATE osm_sts set ftype = 'Lane' WHERE ftype = 'LN';
UPDATE osm_sts set ftype = 'Landing' WHERE ftype = 'LNDG';
UPDATE osm_sts set ftype = 'Loop' WHERE ftype = 'LOOP';
UPDATE osm_sts set ftype = 'Park' WHERE ftype = 'PARK';
UPDATE osm_sts set ftype = 'Path' WHERE ftype = 'PATH';
UPDATE osm_sts set ftype = 'Parkway' WHERE ftype = 'PKWY';
UPDATE osm_sts set ftype = 'Place' WHERE ftype = 'PL';
UPDATE osm_sts set ftype = 'Point' WHERE ftype = 'PT';
UPDATE osm_sts set ftype = 'Ramp' WHERE ftype = 'RAMP';
UPDATE osm_sts set ftype = 'Road' WHERE ftype = 'RD';
UPDATE osm_sts set ftype = 'Ridge' WHERE ftype = 'RDG';
UPDATE osm_sts set ftype = 'Railroad' WHERE ftype = 'RR';
UPDATE osm_sts set ftype = 'Row' WHERE ftype = 'ROW';
UPDATE osm_sts set ftype = 'Run' WHERE ftype = 'RUN';
UPDATE osm_sts set ftype = 'Spur' WHERE ftype = 'SPUR';
UPDATE osm_sts set ftype = 'Square' WHERE ftype = 'SQ';
UPDATE osm_sts set ftype = 'Street' WHERE ftype = 'ST';
UPDATE osm_sts set ftype = 'Terrace' WHERE ftype = 'TER';
UPDATE osm_sts set ftype = 'Trail' WHERE ftype = 'TRL';
UPDATE osm_sts set ftype = 'View' WHERE ftype = 'VW';
UPDATE osm_sts set ftype = 'Walk' WHERE ftype = 'WALK';
UPDATE osm_sts set ftype = 'Way' WHERE ftype = 'WAY';

--e) direction direction
UPDATE osm_sts set oneway = 'yes'
  WHERE (
    direction = 'EB' OR 
    direction = 'WB' OR 
    direction = 'SB' OR
    direction = 'NB' OR
    direction = 'E' OR
    direction = 'N' OR
    direction = 'W' OR
    direction = 'S');

UPDATE osm_sts set direction = 'Eastbound' WHERE direction = 'EB';
UPDATE osm_sts set direction = 'Westbound' WHERE direction = 'WB';
UPDATE osm_sts set direction = 'Southbound' WHERE direction = 'SB';
UPDATE osm_sts set direction = 'Northbound' WHERE direction = 'NB';
UPDATE osm_sts set direction = 'East' WHERE direction = 'E';
UPDATE osm_sts set direction = 'North' WHERE direction = 'N';
UPDATE osm_sts set direction = 'West' WHERE direction = 'W';
UPDATE osm_sts set direction = 'South' WHERE direction = 'S';

--f) put it all together!
--example concat strategy from http://www.laudatio.com/wordpress/2009/04/01/a-better-concat-for-postgresql/
--SELECT ARRAY_TO_STRING(ARRAY[title, firstname, surname], ' ') FROM persons;
UPDATE osm_sts set name = '';
UPDATE osm_sts set name = ARRAY_TO_STRING(ARRAY[prefix, st_name_abb_fix, ftype], ' ');


--4) HIGHWAY TYPE CONVERSIONS
UPDATE osm_sts set highway = '';
UPDATE osm_sts set highway = 'motorway' WHERE (st_class = 1110); --freeways 

--ramps and connectors, will probably need to be reclassed case-by-case
UPDATE osm_sts set highway = 'motorway_link' WHERE (st_class = 1120 OR st_class = 1121 OR st_class = 1122 or st_class = 1123);
UPDATE osm_sts set highway = 'primary_link' WHERE (st_class = 1221 OR st_class = 1222 OR st_class = 1223 OR st_class = 1321);
UPDATE osm_sts set highway = 'secondary_link' WHERE (st_class = 1421 OR st_class = 1471);
UPDATE osm_sts set highway = 'tertiary_link' WHERE st_class = 1521;

UPDATE osm_sts set highway = 'primary' WHERE (st_class = 1200); -- was trunk previously, but I think we should do trunks case-by-case instead
UPDATE osm_sts set highway = 'primary' WHERE (st_class = 1300); -- primary arterial
UPDATE osm_sts set highway = 'secondary' WHERE (st_class = 1400); -- secondary arterial
UPDATE osm_sts set highway = 'tertiary' WHERE (st_class = 1450); -- major residential
UPDATE osm_sts set highway = 'residential' WHERE (st_class = 1500 or st_class = 1550); -- minor residential (cartographic)
UPDATE osm_sts set highway = 'service' WHERE (st_class = 1560); -- minor residential (unclassified)

--alleys (still a few of these, but supposedly removed from rlis)
UPDATE osm_sts set highway = 'service' WHERE (st_class = 1600);
UPDATE osm_sts set service = 'alley' WHERE (st_class = 1600);

--private roads
UPDATE osm_sts set highway = 'residential' WHERE (st_class = 1700);
UPDATE osm_sts set access = 'private' WHERE (st_class = 1700);
UPDATE osm_sts set highway = 'residential' WHERE (st_class = 1740);
UPDATE osm_sts set access = 'private' WHERE (st_class = 1740);

--private service roads
UPDATE osm_sts set highway = 'service' WHERE (st_class = 1760);
UPDATE osm_sts set access = 'private' WHERE (st_class = 1760);

UPDATE osm_sts set highway = 'service' WHERE (st_class = 1750);
UPDATE osm_sts set service = 'driveway' WHERE (st_class = 1750);
UPDATE osm_sts set access = 'private' WHERE (st_class = 1750);

UPDATE osm_sts set highway = 'service' WHERE (st_class = 1800);
UPDATE osm_sts set access = 'private' WHERE (st_class = 1800);

UPDATE osm_sts set highway = 'service' WHERE (st_class = 1850);
UPDATE osm_sts set service = 'driveway' WHERE (st_class = 1850);
UPDATE osm_sts set access = 'private' WHERE (st_class = 1850);

--unimproved roads
UPDATE osm_sts set highway = 'residential' WHERE (st_class = 2000); -- named -> residential
UPDATE osm_sts set highway = 'service' WHERE (st_class = 2000 and name = ''); -- unnamed -> service
UPDATE osm_sts set surface = 'unpaved' WHERE (st_class = 2000);

--with trains
UPDATE osm_sts set highway = 'motorway' WHERE (st_class = 5101 or st_class = 5201);
UPDATE osm_sts set highway = 'primary' WHERE (st_class = 5301);
UPDATE osm_sts set highway = 'secondary' WHERE (st_class = 5401);
UPDATE osm_sts set highway = 'secondary' WHERE (st_class = 5451); --streetcar
UPDATE osm_sts set highway = 'tertiary' WHERE (st_class = 5500 or st_class = 5501);

--etc
UPDATE osm_sts set highway = 'residential' WHERE (st_class = 8224); --unknown type, named
UPDATE osm_sts set highway = 'service' WHERE (st_class = 8224 and name = ''); --unknown type, no name
UPDATE osm_sts set highway = 'track' WHERE (st_class = 9000); --forest roads

--paper streets gone (1900s, 7700)
--trains have been removed from rlis
--trails have been removed from rlis
--no planned sts (1780)
--no census bounds (4000)

--5) Motorway_links should have descriptions, not name and should appear in a form similar to "Sunset-Helvatia Westbound Ramp"
UPDATE osm_sts set description = ARRAY_TO_STRING(ARRAY[prefix, st_name_abb_fix, direction, ftype], ' '), name = '', direction = '' 
    WHERE (highway = 'motorway_link');

--6) Remove 0s in zip columns
UPDATE osm_sts set pc_left = '' WHERE (pc_left = '0');
UPDATE osm_sts set pc_right = '' WHERE (pc_right = '0');


--7) Merge contiguous segment that have the same values for all attributes, this requires the creation of a new table as
--far as I can tell
DROP TABLE IF EXISTS osm_streets_final CASCADE;
CREATE TABLE osm_streets_final WITH OIDS AS
    --st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or multi-polygons) into its
    --individual component parts and creates and entry in the table for each of those parts
    SELECT (ST_Dump(geom)).geom AS geom, name, highway, oneway, access, service, surface,
        pc_left, pc_right, description
    --st_union merges all the grouped features into a single geometry collection and st_linemerege makes 
    --connected segments into single unified lines where possible
    FROM (SELECT ST_LineMerge(ST_Union(geom)) AS geom, name, highway, oneway, access, service, surface,
              pc_left, pc_right, description
          FROM osm_sts
          GROUP BY name, highway, oneway, access, service, surface,
              pc_left, pc_right, description) as unioned_streets;

--Get rid of the temporary table in which all of the translations were made
DROP TABLE IF EXISTS osm_sts CASCADE;


/**
--7) SPLIT INTO COUNTY TABLES

--a) Multnomah
DROP TABLE IF EXISTS mult_streets CASCADE;
CREATE TABLE mult_streets WITH OIDS AS
    SELECT *
    FROM osm_streets_final
    WHERE ST_Intersects(geom, (SELECT geom FROM counties WHERE county = 'Multnomah'));

--b) Washington
DROP TABLE if EXISTS wash_streets cascade;
CREATE TABLE wash_streets WITH OIDS AS
    SELECT *
    FROM osm_streets_final
    WHERE ST_Intersects(geom, (SELECT geom FROM counties WHERE county = 'Washington'));

--c) Clackamas
DROP TABLE if EXISTS clac_streets cascade;
CREATE TABLE clac_streets WITH OIDS AS
    SELECT *
    FROM osm_streets_final
    WHERE ST_Intersects(geom, (SELECT geom FROM counties WHERE county = 'Clackamas'));

**/

--DONE. Ran in 519681 ms on 10/18/12

/**
PGSQL2SHP INSTRUCTIONS
In command prompt go to C:\Program Files\PostgreSQL\9.1\bin (or wherever your pgsql2shp is located)

Enter the following to export the shapefile to your local system (change directory as needed), or use QGIS instead to connect to db and use “save as”:

pgsql2shp -k -u username -P password -f file\path.shp database_name schema.table_name
the 'k' parameter preserves the case of the column names, schema only needs to be entered if different than 'public'

examples:
pgsql2shp -k -u postgres -P postgres -f P:\TEMP\RLISsts.shp rlis_streets osm_sts
pgsql2shp -k -u postgres -P postgres -f P:\TEMP\Multsts.shp rlis_streets mult_sts
pgsql2shp -k -u postgres -P postgres -f P:\TEMP\Washsts.shp rlis_streets wash_sts
pgsql2shp -k -u postgres -P postgres -f P:\TEMP\Clacsts.shp rlis_streets clac_sts

Then run ogr2osm to convert from shapefile to .osm use the following command in the OSGeo4W window, or anywhere where GDAL is set up 
with python bindings (which can be tough to do on Windows w/o OSGeo4W):
Navigate the folder that contains the ogr2osm script then enter the following:
python ogr2osm.py -f -e <projection epsg> -o <output/file/path> -t <translation file> <input file>
The translation file converts tags to more OSM friendly format (but of course you must write this code), we've chosen to handle most of
this in SQL/PostGIS, but I've written a translation files for streets and trails that put the finishing touches on things

example:
python ogr2osm.py -f -e 2913 -o P:\TEMP\clack_streets.osm -t rlis_streets_trans.py P:\TEMP\clac_sts.shp
**/

--return client encoding to default setting, change is specific to the windows environment 
--that this script is being run in using a batch file with the command prompt, the command
--below and its complement at the beginning of the script can be removed if it causes
--problems in other environments
reset client_encoding;