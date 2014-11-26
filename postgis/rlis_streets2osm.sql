--RLIS streets to OSM attribute conversion
--Grant Humphries + Melelani Sax-Barnett for TriMet, 2012-2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--ensuring that client encoding is 'UTF8', on when this script is called from a
--batch file on windows 7 the encoding is 'WIN1252' which cause errors to be thrown
set client_encoding to 'UTF8';

vaccum analyze rlis_streets;

--1) create table to hold osm streets
drop table if exists osm_sts_staging cascade;
create table osm_sts_staging (
	id serial primary key,
	geom geometry,
	access text,
	description text,
	highway text,
	layer text,
	name text,
	oneway text,
	service text,
	surface text,
	--fields below are for staging
	st_prefix text,
	st_name text,
	st_type text
	st_direction text
);

--2) Populate osm_streets from rlis rlis_streets
insert into osm_sts_staging (geom, st_prefix, st_name, st_type, st_direction, oneway, 
		highway, service, access, surface, layer)
	select rs.geom, 
		--expand street name prefix
		case when prefix ilike 'N' then 'North'
			when prefix ilike 'NE' then 'Northweast'
			when prefix ilike 'E' then 'East'
			when prefix ilike 'SE' then 'Southeast'
			when prefix ilike 'S' then 'South'
			when prefix ilike 'SW' then 'Southwest'
			when prefix ilike 'W' then 'West'
			when prefix ilike 'NW' then 'Northwest'
			else null end,
		--convert street name to titlecase
		format_titlecase(streetname),
		--expand street type suffix
		case when ftype ilike 'ALY' then 'Alley'
			when ftype ilike 'AVE' then 'Avenue'
			when ftype ilike 'BLVD' then 'Boulevard'
			when ftype ilike 'BRG' then 'Bridge'
			when ftype ilike 'CIR' then 'Circle'
			when ftype ilike 'CORR' then 'Corridor'
			when ftype ilike 'CRST' then 'Crest'
			when ftype ilike 'CT' then 'Court'
			when ftype ilike 'DR' then 'Drive'
			when ftype ilike 'EXPY' then 'Expressway'
			when ftype ilike 'FRTG' then 'Frontage Road'
			when ftype ilike 'FWY' then 'Freeway'
			when ftype ilike 'HTS' then 'Heights'
			when ftype ilike 'HWY' then 'Highway'
			when ftype ilike 'LN' then 'Lane'
			when ftype ilike 'LNDG' then 'Landing'
			when ftype ilike 'PKWY' then 'Parkway'
			when ftype ilike 'PL' then 'Place'
			when ftype ilike 'PT' then 'Point'
			when ftype ilike 'RD' then 'Road'
			when ftype ilike 'RDG' then 'Ridge'
			when ftype ilike 'RR' then 'Railroad'
			when ftype ilike 'SQ' then 'Square'
			when ftype ilike 'ST' then 'Street'
			when ftype ilike 'TER' then 'Terrace'
			when ftype ilike 'TRL' then 'Trail'
			when ftype ilike 'VIA' then 'Viaduct'			
			when ftype ilike 'VW' then 'View'
			--if not in this list, put original value in title case
			else upper(substring(ftype from 1 for 1)) || 
				lower(substring(ftype from 2 for length(ftype))) end,
		--traffic direction type
		case when direction ilike 'N' then 'North'
			when direction ilike 'NB' then 'Northbound'
			when direction ilike 'E' then 'East'
			when direction ilike 'EB' then 'Eastbound'
			when direction ilike 'S' then 'South'
			when direction ilike 'SB' then 'Southbound'
			when direction ilike 'W' then 'West'
			when direction ilike 'WB' then 'Westbound'
			else null end,
		--oneway (not much information about this in rlis, but if it has a direction qualifier it
		--is always oneway)
		case when direction is not null then 'yes'
			else null end,
		--osm highway type, metadata on rlis street types is here:
		--http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=556#
		case when rs.type in (1110, 5101, 5201) then 'motorway'
			when rs.type in (1120, 1121, 1122, 1123) then 'motorway_link'
			--none of the rlis classes really map to trunk
			when rs.type in (1200, 1300, 5301) then 'primary'
			when rs.type in (1221, 1222, 1223, 1321) then 'primary_link'
			when rs.type in (1400, 5401, 5451) then 'secondary'
			when rs.type in (1421, 1471) then 'secondary_link'
			when rs.type in (1450, 5402, 5500, 5501) then 'tertiary'
			when rs.type in (1521) then 'tertiary_link'
			--residential streets should always be named otherwise they're service roads
			when rs.type in (1500, 1550, 1700, 1740, 2000, 8224) 
				and streetname is not null then 'residential'
			when rs.type in (1500, 1550, 1560, 1600, 1700, 
				1740, 1750, 1760, 1800, 1850, 2000, 8224) then 'service'
			when rs.type in (9000) then 'track'
			else null end,
		--service type (this is a modifier to highway=service)
		case when rs.type in (1600) then 'alley'
			when rs.type in (1750, 1850) then 'driveway'
			else null end,
		--access permissions
		case when rs.type in (1700, 1740, 1750, 1760, 1800, 1850) then 'private'
			when rs.type in (5402) then 'no'
			else null end,
		--surface
		case when rd.type in (2000) then 'unpaved'
			else null end,
		--street layer, ground level layer is 1 for rlis, but 0 for osm
		case when f_zlev = t_zlev then
				case when f_zlev = 1 then null 
					when f_zlev > 0 then f_zlev - 1
					when f_zlev < 0 then f_zlev end
			else
				case when f_zlev > 0 and t_zlev < 0 then t_zlev
					when f_zlev > 0 and t_zlev > 0 then greatest(f_zlev, t_zlev) - 1
					when f_zlev < 0 and t_zlev < 0 then least(f_zlev, t_zlev)
					when f_zlev < 0 and t_zlev > 0 then f_zlev end
			end,
	from rlis_streets rs;

vaccum analyze osm_sts_staging;

--b) Proper case basic name
--Below function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> 
--http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php

/* Examples
select * from Format_TitleCase('MR DOG BREATH');
select * from Format_TitleCase('each word, mcclure of this string:shall be transformed');
select * from Format_TitleCase(' EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
select * from Format_TitleCase('mcclure and others');
select * from Format_TitleCase('J & B ART');
select * from Format_TitleCase('J&B ART');
select * from Format_TitleCase('J&B ART J & B ART this''s art''s house''s problem''s 0''shay o''should work''s EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
*/

create or replace function "format_titlecase" ("v_inputstring" varchar)
returns varchar as
$body$

declare
	v_Index int;
	v_Char char(1);
	v_OutputString varchar(4000);
	SWV_InputString varchar(4000);

begin
	SWV_InputString := v_InputString;
	--cures problem where string starts with blank space and removes back-to-back spaces
	SWV_InputString := regexp_replace(ltrim(rtrim(SWV_InputString)), '\s+', '\s'); 
	v_OutputString := lower(SWV_InputString);
	v_Index := 1;
	--replaces 1st char of Output with uppercase of 1st char from input
	v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString, 1, 1)) from 1 for 1); 
	
	while v_Index <= length(SWV_InputString) loop
		v_Char := substr(SWV_InputString, v_Index, 1); 
		--gets loop's working character
		if v_Char in ('m','M',' ',';',':','!','?',',','.','_','-','/','&','''','(',chr(9),'0','1','2','3','4','5','6','7','8','9') then
			if v_Index+1 <= length(SWV_InputString) then
				--if the working char is an apostrophe and the letter after that is not S
				if v_Char = '''' and upper(substr(SWV_InputString,v_Index+1,1)) <> 'S' and substr(SWV_InputString,v_Index+2,1) <> repeat(' ',1) then
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
				--if the working char is an &
				elsif v_Char = '&' then
					if(substr(SWV_InputString,v_Index+1,1)) = ' ' then
						v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
					else
						v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
					end if;
				--if working character is not 'm', in this case I want single letter words to be capitalized
				--if that's not the case add the clause that the second character after the working character 
				--cannot be a space
				elsif upper(v_Char) != 'M' and (substr(SWV_InputString,v_Index+1,1) <> repeat(' ',1)) then
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
				--special case for handling 'Mc' as in McDonald
				elsif upper(v_Char) = 'M' and upper(substr(SWV_InputString,v_Index+1,1)) = 'C' and (substring(SWV_InputString,v_Index-1,1) in (' ','-') or v_Index=1) then
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index,1)) from v_Index for 1);
					--makes the 'C' lower case.
					v_OutputString := overlay(v_OutputString placing lower(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
					--makes the letter after the 'c' upper case
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
					--we took care of the char acfter 'c' (we handled 2 letters instead of only 1 as usual), so we need to advance.
					v_Index := v_Index+1;
				end if;
			end if;
		end if;

		v_Index := v_Index+1;
	end loop; 

	return coalesce(v_OutputString,'');
end;
$body$
language 'plpgsql'
volatile
called on null input
security invoker
cost 100;


--Expand street suffixes that are within street basename
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Av[e]?(-|\s|$)', '\1Avenue\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Blvd(-|\s|$)', '\1Boulevard\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Brg(-|\s|$)', '\1Bridge\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Ct(-|\s|$)', '\1Court\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Dr(-|\s|$)', '\1Drive\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Fwy(-|\s|$)', '\1Freeway\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Pkwy(-|\s|$)', '\1Parkway\2 ', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Pl(-|\s|$)', '\1Place\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Rd(-|\s|$)', '\1Road\2 ', 'g')
--St--> Street (will not occur at beginning of a streetname)
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)St(-|\s|$)', '\1Street\2 ', 'g');

--Expand other abbreviated parts of street basename
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Cc(-|\s|$)', '\1Community College\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Co(-|\s|$)', '\1County\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Ft Of(-|\s|$)', '\1Foot of\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Jr(-|\s|$)', '\1Junior\2', 'g');
--Mt at beginning of name is 'Mount' later in name is 'Mountain'
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|-|-\s)Mt(\s)', '\1Mount\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Mt(-|\s|$)', '\1Mountain\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Nfd(-|\s|$)', '\1National Forest Development Road\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(\s)Tc(-|\s|$)', '\1Transit Center\2', 'g');
--St--> Saint (will only occur at the beginning of a street name)
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|-|-\s)(Mt\s|Mount\s|Old\s)?St[.]?(\s)', '\1\2Saint\3', 'g');
update osm_sts_staging set streetname = 
	regexp_replace(streetname, '(^|\s|-)Us(-|\s|$)', '\1United States\2', 'g');


update osm_sts_staging set streetname = 
	case when streetname != regexp_replace(streetname, 
		'(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3', 'g')
	then format_titlecase(regexp_replace(streetname, 
		'(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3', 'g'))
	else streetname end;


update osm_sts_staging set streetname = 
	case when streetname != regexp_replace(streetname, 
		'(^|\s|-)Ft\sOf\s(N|Se)(\s)(Holladay|Madison|Marion)(-|\s|$)', '\1Foot of \2\3\4\5' 'g')
	then format_titlecase(regexp_replace(streetname, 
		'(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3', 'g'))
	else streetname end;

--super special cases
--for these create an index and match the full name of the field to decrease run time of script
drop index if exists streetname_ix cascade;
create index streetname_ix on osm_sts_staging using BTREE (streetname);

vacuum analyze osm_sts_staging;

update osm_sts_staging set streetname = 'Bpa'
	where streetname ='Bonneville Power Administration';
update osm_sts_staging set streetname = 'Jq Adams'
	where streetname ='JQ Adams';
update osm_sts_staging set streetname = 'Sunnyside Hosp-Mount Scott Med Transit Center'
	where streetname ='Sunnyside Hospital-Mount Scott Medical Transit Center';


update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of N Holladay', 'North Holladay');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of Se Madison', 'Southeast Madison');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of Se Marion', 'Southeast Marion');

update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Obrien', 'O’Brien');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oday', 'O’Day');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oneal', 'O’Neal');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oneill', 'O’Neill');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oneil', 'O’Neil');


--Now that abbreviations in street names have been expanded concatenate their parts
--concat strategy via http://www.laudatio.com/wordpress/2009/04/01/a-better-concat-for-postgresql/
update osm_sts_staging set 
	name = array_to_string(array[prefix, streetname, ftype, direction], ' ')
	where highway != 'motorway_link' 
		or highway is not null;

--motorway_link's shouldn't have names, but rather descriptions in osm
--source: http://wiki.openstreetmap.org/wiki/Link_%28highway%29
update osm_sts_staging set 
	description = array_to_string(array[prefix, streetname, ftype, direction], ' ')
	where highway = 'motorway_link';


--Merge contiguous segment that have the same values for all attributes, this 
--requires the creation of a new table
drop table if exists osm_streets cascade;
create table osm_streets with oids as
	--st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or multi-polygons) into its
	--individual component parts and creates and entry in the table for each of those parts
	select (ST_Dump(geom)).geom as geom, access, description,
		highway, layer, name, oneway, service, surface
	--st_union merges all the grouped features into a single geometry collection and st_linemerege makes 
	--connected segments into single unified lines where possible
	from (select ST_LineMerge(ST_Union(geom)) as geom, access, description,
				highway, layer, name, oneway, service, surface
			from osm_sts_staging 
			group by access, description, highway, layer, name, oneway,
				service, surface) as unioned_streets;



--DONE. Ran in 519681 ms on 10/18/12

/**
Then run ogr2osm to convert from shapefile to .osm use the following command in the OSGeo4W window, or anywhere where GDAL is set up 
with python bindings (which can be tough to do on Windows w/o OSGeo4W):
Navigate the folder that contains the ogr2osm script then enter the following:
python ogr2osm.py -f -e <projection epsg> -o <output/file/path> -t <translation file> <input file>
The translation file converts tags to more OSM friendly format (but of course you must write this code), we've chosen to handle most of
this in SQL/PostGIS, but I've written a translation files for streets and trails that put the finishing touches on things

example:
python ogr2osm.py -f -e 2913 -o P:\temp\clack_streets.osm -t rlis_streets_trans.py P:\temp\clac_sts.shp
**/

reset client_encoding;