--RLIS streets to OSM attribute conversion
--Grant Humphries + Melelani Sax-Barnett for TriMet, 2012-2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--client encoding is being changed from 'WIN1252' to 'UTF8', the when in the former state
--an error was being thrown when running this script with a batch file on Windows 7.  The
--command below and its complement at the end of the script can be removed if it causes
--problems in other environments
set client_encoding to 'UTF8';

--1) create table to hold osm streets
drop table if exists osm_streets cascade;
create table osm_streets (
	id serial primary key,
	geom geometry,
	name text,
	description text,
	highway text,
	service text,
	oneway text,
	access text,
	surface text,
	layer text,
	addr_postcode_left text, --to be renamed addr:postcode:left
	addr_postcode_right text, --to be renamed addr:postcode:right
	--these fields won't appear in the final output
	prefix text,
	streetname text,
	streettype text
	st_name_proper text,
	st_name_abb_fix text,
	ftype text,
	direction text,
	st_class bigint,
	lcounty text,
	rcounty text
);

--2) POPULATE osm_streets from rlis rlis_streets
insert into osm_streets (geom, highway, prefix, streetname, ftype, direction, st_class, pc_left, pc_right, lcounty, rcounty)
	select rs.geom, 
		--meta data on rlis street types is here:
		--http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=556#
		case when rs.type in (1100, 5101, 5201) then 'motorway'
			when rs.type in (1120, 1121, 1122, 1123) then 'motorway_link'
			--trunk/trunk_link would be here, but they're odd so are done case-by-case
			when rs.type in (1200, 1300, 5301) then 'primary'
			when rs.type in (1221, 1222, 1223, 1321) then 'primary_link'
			when rs.type in (1400) then 'secondary'
			when rs.type in (1421, 1471) then 'secondary_link'
			when rs.type in (1450) then 'tertiary'
			when rs.type in (1521) then 'tertiary_link'
			when rs.type in (1500, 1550, 1700, 1740) then 'residential'
			when rs.type in (1560, 1600, 1750, 1760, 1800, 1850) then 'service'
	rs.prefix, rs.streetname, rs.ftype, rs.direction, rs.type, rs.leftzip, rs.rightzip, rs.lcounty, rs.rcounty
	from rlis_streets rs;


--4) HIGHWAY TYPE CONVERSIONS

--update osm_streets set highway = 'motorway' where (st_class = 1110); --freeways 

--ramps and connectors, will probably need to be reclassed case-by-case
--update osm_streets set highway = 'motorway_link' where (st_class = 1120 or st_class = 1121 or st_class = 1122 or st_class = 1123);
--update osm_streets set highway = 'primary_link' where (st_class = 1221 or st_class = 1222 or st_class = 1223 or st_class = 1321);
--update osm_streets set highway = 'secondary_link' where (st_class = 1421 or st_class = 1471);
--update osm_streets set highway = 'tertiary_link' where st_class = 1521;

--update osm_streets set highway = 'primary' where (st_class = 1200); -- was trunk previously, but I think we should do trunks case-by-case instead
--update osm_streets set highway = 'primary' where (st_class = 1300); -- primary arterial
--update osm_streets set highway = 'secondary' where (st_class = 1400); -- secondary arterial
--update osm_streets set highway = 'tertiary' where (st_class = 1450); -- major residential
--update osm_streets set highway = 'residential' where (st_class = 1500 or st_class = 1550); -- minor residential (cartographic)
--update osm_streets set highway = 'service' where (st_class = 1560); -- minor residential (unclassified)

--alleys (still a few of these, but supposedly removed from rlis)
--update osm_streets set highway = 'service' where (st_class = 1600);
update osm_streets set service = 'alley' where (st_class = 1600);

--private roads
--update osm_streets set highway = 'residential' where (st_class = 1700);
update osm_streets set access = 'private' where (st_class = 1700);
--update osm_streets set highway = 'residential' where (st_class = 1740);
update osm_streets set access = 'private' where (st_class = 1740);

--private service roads
--update osm_streets set highway = 'service' where (st_class = 1760);
update osm_streets set access = 'private' where (st_class = 1760);

--update osm_streets set highway = 'service' where (st_class = 1750);
update osm_streets set service = 'driveway' where (st_class = 1750);
update osm_streets set access = 'private' where (st_class = 1750);

--update osm_streets set highway = 'service' where (st_class = 1800);
update osm_streets set access = 'private' where (st_class = 1800);

--update osm_streets set highway = 'service' where (st_class = 1850);
update osm_streets set service = 'driveway' where (st_class = 1850);
update osm_streets set access = 'private' where (st_class = 1850);

--unimproved roads
update osm_streets set highway = 'residential' where (st_class = 2000); -- named -> residential
update osm_streets set highway = 'service' where (st_class = 2000 and name = ''); -- unnamed -> service
update osm_streets set surface = 'unpaved' where (st_class = 2000);

--with trains
--update osm_streets set highway = 'motorway' where (st_class = 5101 or st_class = 5201);
--update osm_streets set highway = 'primary' where (st_class = 5301);
update osm_streets set highway = 'secondary' where (st_class = 5401);
update osm_streets set highway = 'secondary' where (st_class = 5451); --streetcar
update osm_streets set highway = 'tertiary' where (st_class = 5500 or st_class = 5501);

--etc
update osm_streets set highway = 'residential' where (st_class = 8224); --unknown type, named
update osm_streets set highway = 'service' where (st_class = 8224 and name = ''); --unknown type, no name
update osm_streets set highway = 'track' where (st_class = 9000); --forest roads

--3) NAME CONVERSIONS
--a) Prefix
update osm_streets set prefix = 'Northwest'
	where prefix = 'NW';
update osm_streets set prefix = 'Southwest'
	where prefix = 'SW';
update osm_streets set prefix = 'Southeast'
	where prefix = 'SE';
update osm_streets set prefix = 'Northeast'
	where prefix = 'NE';
update osm_streets set prefix = 'North'
	where prefix = 'N';
update osm_streets set prefix = 'East'
	where prefix = 'E';
update osm_streets set prefix = 'South'
	where prefix = 'S';
update osm_streets set prefix = 'West'
	where prefix = 'W';

--b) Proper case basic name
--Below function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php
create or replace function "format_titlecase" (
	"v_inputstring" varchar
)
returns varchar as
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

declare
   v_Index int;
   v_Char char(1);
   v_OutputString varchar(4000);
   SWV_InputString varchar(4000);

begin
   SWV_InputString := v_InputString;
   SWV_InputString := ltrim(rtrim(SWV_InputString)); --cures problem where string starts with blank space
   v_OutputString := lower(SWV_InputString);
   v_Index := 1;
   v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,1,1)) from 1 for 1); -- replaces 1st char of Output with uppercase of 1st char from Input
   while v_Index <= length(SWV_InputString) loop
	  v_Char := substr(SWV_InputString,v_Index,1); -- gets loop's working character
	  if v_Char IN('m','M','',';',':','!','?',',','.','_','-','/','&','''','(',chr(9)) then
		 --end4
		 if v_Index+1 <= length(SWV_InputString) then
			if v_Char = '''' and upper(substr(SWV_InputString,v_Index+1,1)) <> 'S' and substr(SWV_InputString,v_Index+2,1) <> repeat(' ',1) then  -- if the working char is an apost and the letter after that is not S
			   v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
			else 
			   if v_Char = '&' then -- if the working char is an &
				  if(substr(SWV_InputString,v_Index+1,1)) = ' ' then
					 v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
				  else
					 v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
				  end if;
			   else
				  if upper(v_Char) != 'M' and (substr(SWV_InputString,v_Index+1,1) <> repeat(' ',1) and substr(SWV_InputString,v_Index+2,1) <> repeat(' ',1)) then
					 v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
				  end if;
			   end if;
			end if;

					-- special case for handling "Mc" as in McDonald
			if upper(v_Char) = 'M' and upper(substr(SWV_InputString,v_Index+1,1)) = 'C' then
			   v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index,1)) from v_Index for 1);
							--MAKES THE C lower CasE.
			   v_OutputString := overlay(v_OutputString placing lower(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
							-- makes the letter after the C upper case
			   v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
							--WE TOOK CARE OF THE CHAR AFTER THE C (we handled 2 letters instead of only 1 as usual), SO WE NEED TO ADVANCE.
			   v_Index := v_Index+1;
			end if;
		 end if;
	  end if; --end3

	  v_Index := v_Index+1;
   end loop; --end2

   return coalesce(v_OutputString,'');
end;
$body$
language 'plpgsql'
volatile
called on null input
security invoker
cost 100;

--mine
update osm_streets set st_name_proper = format_titlecase(streetname);

--c) Deal with abbreviations/common fixes in st_name_proper
update osm_streets set st_name_abb_fix = st_name_proper;

drop index if exists st_name_abb_fix_ix cascade;
create index st_name_abb_fix_ix ON osm_streets using BTREE (st_name_abb_fix);

update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Hwy', 'Highway');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Fwy', 'Freeway');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Pkwy', 'Parkway');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Blvd', 'Boulevard');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Co Rd', 'County Road');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Rd', 'Road');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Brg', 'Bridge');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Pl ', 'Place ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Pl-', 'Place-');
--Pl at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Place' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 2) = 'Pl';

--Ave
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ave-', 'Avenue-');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ave ', 'Avenue ');
--Ave at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Avenue' from (char_length(st_name_abb_fix) - 2) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 3) = 'Ave';
--Av at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Avenue' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 2) = 'Av';

--St
--St at beginning of field (Saint)
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Saint ' from 1 for 3) 
	where left(st_name_abb_fix, 3) = 'St ';
--Mount Saint...
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Mt St ', 'Mount Saint ');
--Old Saint...
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Old St ', 'Old Saint ');
--"St."
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'St.', 'Saint');
--"St-"
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'St-', 'Street-');
--St at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Street' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 2) = 'St';
--remaining cases
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'St ', 'Street ');

--Dr
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Dr-', 'Drive-');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Dr ', 'Drive ');
--Dr at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Drive' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 2) = 'Dr';

update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ct ', 'Court ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ct-', 'Court-');
--Ct at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Court' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 2) = 'Ct';

update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Jr ', 'Junior ');
--Jr at end of field
update osm_streets set st_name_abb_fix = overlay(st_name_abb_fix placing 'Junior' from (char_length(st_name_abb_fix) - 1) for char_length(st_name_abb_fix)) 
	where right(st_name_abb_fix, 2) = 'Jr';

update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Tc', 'Transit Center');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Us ', 'United States ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Med ', 'Medical ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Hosp ', 'Hospital ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Hosp/', 'Hospital/');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Mt ', 'Mount ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Cc', 'Community College');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Nfd ', 'National Forest Development ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Mtn', 'Mountain');

--super special cases
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Bpa', 'Bonneville Power Administration');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Cesar e Chavez', 'Cesar E Chavez');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'ArMcO', 'ARMCO');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of n Holladay', 'North Holladay');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of Se Madison', 'Southeast Madison');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Ft Of Se Marion', 'Southeast Marion');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, '99e', '99E');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, '99w', '99W');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Jq ', 'JQ ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, ' o ', ' O ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, ' w ', ' W ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, ' v ', ' V ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, ' s ', ' S ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Obrien', 'O’Brien');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oday', 'O’Day');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oneal', 'O’Neal');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oneill', 'O’Neill');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Oneil', 'O’Neil');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Pcc ', 'Portland Community College ');
update osm_streets set st_name_abb_fix = replace(st_name_abb_fix, 'Portland Traction Co', 'Portland Traction Company');

--d) ftype (street type)
update osm_streets set ftype = 'Alley' where ftype = 'ALY';
update osm_streets set ftype = 'Avenue' where ftype = 'AVE';
update osm_streets set ftype = 'Boulevard' where ftype = 'BLVD';
update osm_streets set ftype = 'Bridge' where ftype = 'BRG';
update osm_streets set ftype = 'Circle' where ftype = 'CIR';
update osm_streets set ftype = 'Corridor' where ftype = 'CORR';
update osm_streets set ftype = 'Crescent' where ftype = 'CRST';
update osm_streets set ftype = 'Court' where ftype = 'CT';
update osm_streets set ftype = 'Drive' where ftype = 'DR';
update osm_streets set ftype = 'Expressway' where ftype = 'EXPY';
update osm_streets set ftype = 'Frontage' where ftype = 'FRTG';
update osm_streets set ftype = 'Freeway' where ftype = 'FWY';
update osm_streets set ftype = 'Highway' where ftype = 'HWY';
update osm_streets set ftype = 'Lane' where ftype = 'LN';
update osm_streets set ftype = 'Landing' where ftype = 'LNDG';
update osm_streets set ftype = 'Loop' where ftype = 'loop';
update osm_streets set ftype = 'Park' where ftype = 'PARK';
update osm_streets set ftype = 'Path' where ftype = 'PATH';
update osm_streets set ftype = 'Parkway' where ftype = 'PKWY';
update osm_streets set ftype = 'Place' where ftype = 'PL';
update osm_streets set ftype = 'Point' where ftype = 'PT';
update osm_streets set ftype = 'Ramp' where ftype = 'RAMP';
update osm_streets set ftype = 'Road' where ftype = 'RD';
update osm_streets set ftype = 'Ridge' where ftype = 'RDG';
update osm_streets set ftype = 'Railroad' where ftype = 'RR';
update osm_streets set ftype = 'Row' where ftype = 'ROW';
update osm_streets set ftype = 'Run' where ftype = 'RUN';
update osm_streets set ftype = 'Spur' where ftype = 'SPUR';
update osm_streets set ftype = 'Square' where ftype = 'SQ';
update osm_streets set ftype = 'Street' where ftype = 'ST';
update osm_streets set ftype = 'Terrace' where ftype = 'TER';
update osm_streets set ftype = 'Trail' where ftype = 'TRL';
update osm_streets set ftype = 'View' where ftype = 'VW';
update osm_streets set ftype = 'Walk' where ftype = 'WALK';
update osm_streets set ftype = 'Way' where ftype = 'WAY';

--e) direction direction
update osm_streets set oneway = 'yes'
  where (
	direction = 'EB' or
	direction = 'WB' or
	direction = 'SB' or
	direction = 'NB' or
	direction = 'E' or
	direction = 'N' or
	direction = 'W' or
	direction = 'S');

update osm_streets set direction = 'Eastbound' where direction = 'EB';
update osm_streets set direction = 'Westbound' where direction = 'WB';
update osm_streets set direction = 'Southbound' where direction = 'SB';
update osm_streets set direction = 'Northbound' where direction = 'NB';
update osm_streets set direction = 'East' where direction = 'E';
update osm_streets set direction = 'North' where direction = 'N';
update osm_streets set direction = 'West' where direction = 'W';
update osm_streets set direction = 'South' where direction = 'S';

--f) put it all together!
--example concat strategy from http://www.laudatio.com/wordpress/2009/04/01/a-better-concat-for-postgresql/
--select array_to_string(array[title, firstname, surname], ' ') from persons;
update osm_streets set name = '';
update osm_streets set name = array_to_string(array[prefix, st_name_abb_fix, ftype], ' ');


--4) HIGHWAY TYPE CONVERSIONS
update osm_streets set highway = '';
update osm_streets set highway = 'motorway' where (st_class = 1110); --freeways 

--ramps and connectors, will probably need to be reclassed case-by-case
update osm_streets set highway = 'motorway_link' where (st_class = 1120 or st_class = 1121 or st_class = 1122 or st_class = 1123);
update osm_streets set highway = 'primary_link' where (st_class = 1221 or st_class = 1222 or st_class = 1223 or st_class = 1321);
update osm_streets set highway = 'secondary_link' where (st_class = 1421 or st_class = 1471);
update osm_streets set highway = 'tertiary_link' where st_class = 1521;

update osm_streets set highway = 'primary' where (st_class = 1200); -- was trunk previously, but I think we should do trunks case-by-case instead
update osm_streets set highway = 'primary' where (st_class = 1300); -- primary arterial
update osm_streets set highway = 'secondary' where (st_class = 1400); -- secondary arterial
update osm_streets set highway = 'tertiary' where (st_class = 1450); -- major residential
update osm_streets set highway = 'residential' where (st_class = 1500 or st_class = 1550); -- minor residential (cartographic)
update osm_streets set highway = 'service' where (st_class = 1560); -- minor residential (unclassified)

--alleys (still a few of these, but supposedly removed from rlis)
update osm_streets set highway = 'service' where (st_class = 1600);
update osm_streets set service = 'alley' where (st_class = 1600);

--private roads
update osm_streets set highway = 'residential' where (st_class = 1700);
update osm_streets set access = 'private' where (st_class = 1700);
update osm_streets set highway = 'residential' where (st_class = 1740);
update osm_streets set access = 'private' where (st_class = 1740);

--private service roads
update osm_streets set highway = 'service' where (st_class = 1760);
update osm_streets set access = 'private' where (st_class = 1760);

update osm_streets set highway = 'service' where (st_class = 1750);
update osm_streets set service = 'driveway' where (st_class = 1750);
update osm_streets set access = 'private' where (st_class = 1750);

update osm_streets set highway = 'service' where (st_class = 1800);
update osm_streets set access = 'private' where (st_class = 1800);

update osm_streets set highway = 'service' where (st_class = 1850);
update osm_streets set service = 'driveway' where (st_class = 1850);
update osm_streets set access = 'private' where (st_class = 1850);

--unimproved roads
update osm_streets set highway = 'residential' where (st_class = 2000); -- named -> residential
update osm_streets set highway = 'service' where (st_class = 2000 and name = ''); -- unnamed -> service
update osm_streets set surface = 'unpaved' where (st_class = 2000);

--with trains
update osm_streets set highway = 'motorway' where (st_class = 5101 or st_class = 5201);
update osm_streets set highway = 'primary' where (st_class = 5301);
update osm_streets set highway = 'secondary' where (st_class = 5401);
update osm_streets set highway = 'secondary' where (st_class = 5451); --streetcar
update osm_streets set highway = 'tertiary' where (st_class = 5500 or st_class = 5501);

--etc
update osm_streets set highway = 'residential' where (st_class = 8224); --unknown type, named
update osm_streets set highway = 'service' where (st_class = 8224 and name = ''); --unknown type, no name
update osm_streets set highway = 'track' where (st_class = 9000); --forest roads

--paper streets gone (1900s, 7700)
--trains have been removed from rlis
--trails have been removed from rlis
--no planned sts (1780)
--no census bounds (4000)

--5) Motorway_links should have descriptions, not name and should appear in a form similar to "Sunset-Helvatia Westbound Ramp"
update osm_streets set description = array_to_string(array[prefix, st_name_abb_fix, direction, ftype], ' '), name = '', direction = '' 
	where (highway = 'motorway_link');

--6) Remove 0s in zip columns
update osm_streets set pc_left = '' where (pc_left = '0');
update osm_streets set pc_right = '' where (pc_right = '0');


--7) Merge contiguous segment that have the same values for all attributes, this requires the creation of a new table as
--far as I can tell
drop table if exists osm_streets_final cascade;
create table osm_streets_final with oids as
	--st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or multi-polygons) into its
	--individual component parts and creates and entry in the table for each of those parts
	select (ST_Dump(geom)).geom as geom, name, highway, oneway, access, service, surface,
		pc_left, pc_right, description
	--st_union merges all the grouped features into a single geometry collection and st_linemerege makes 
	--connected segments into single unified lines where possible
	from (select ST_LineMerge(ST_Union(geom)) as geom, name, highway, oneway, access, service, surface,
			  pc_left, pc_right, description
		  from osm_streets
		  group by name, highway, oneway, access, service, surface,
			  pc_left, pc_right, description) as unioned_streets;

--Get rid of the temporary table in which all of the translations were made
drop table if exists osm_streets cascade;


/**
--7) SPLIT into COUNTY TABLES

--a) Multnomah
drop table if exists mult_streets cascade;
create table mult_streets with oids as
	select *
	from osm_streets_final
	where ST_Intersects(geom, (select geom from counties where county = 'Multnomah'));

--b) Washington
drop table if exists wash_streets cascade;
create table wash_streets with oids as
	select *
	from osm_streets_final
	where ST_Intersects(geom, (select geom from counties where county = 'Washington'));

--c) Clackamas
drop table if exists clac_streets cascade;
create table clac_streets with oids as
	select *
	from osm_streets_final
	where ST_Intersects(geom, (select geom from counties where county = 'Clackamas'));

**/

--DONE. Ran in 519681 ms on 10/18/12

/**
PGSQL2SHP INSTRUCTIONS
In command prompt go to C:\Program Files\PostgreSQL\9.1\bin (or wherever your pgsql2shp is located)

Enter the following to export the shapefile to your local system (change directory as needed), or use QGIS instead to connect to db and use “save as”:

pgsql2shp -k -u username -P password -f file\path.shp database_name schema.table_name
the 'k' parameter preserves the case of the column names, schema only needs to be entered if different than 'public'

examples:
pgsql2shp -k -u postgres -P postgres -f P:\temp\RLISsts.shp rlis_streets osm_streets
pgsql2shp -k -u postgres -P postgres -f P:\temp\Multsts.shp rlis_streets mult_sts
pgsql2shp -k -u postgres -P postgres -f P:\temp\Washsts.shp rlis_streets wash_sts
pgsql2shp -k -u postgres -P postgres -f P:\temp\Clacsts.shp rlis_streets clac_sts

Then run ogr2osm to convert from shapefile to .osm use the following command in the OSGeo4W window, or anywhere where GDAL is set up 
with python bindings (which can be tough to do on Windows w/o OSGeo4W):
Navigate the folder that contains the ogr2osm script then enter the following:
python ogr2osm.py -f -e <projection epsg> -o <output/file/path> -t <translation file> <input file>
The translation file converts tags to more OSM friendly format (but of course you must write this code), we've chosen to handle most of
this in SQL/PostGIS, but I've written a translation files for streets and trails that put the finishing touches on things

example:
python ogr2osm.py -f -e 2913 -o P:\temp\clack_streets.osm -t rlis_streets_trans.py P:\temp\clac_sts.shp
**/

--return client encoding to default setting, change is specific to the windows environment 
--that this script is being run in using a batch file with the command prompt, the command
--below and its complement at the beginning of the script can be removed if it causes
--problems in other environments
reset client_encoding;