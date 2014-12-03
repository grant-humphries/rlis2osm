--RLIS streets to OSM attribute conversion
--Grant Humphries + Melelani Sax-Barnett for TriMet, 2012-2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--ensuring that client encoding is 'UTF8', on when this script is called from a
--batch file on windows 7 the encoding is 'WIN1252' which cause errors to be thrown
set client_encoding to 'UTF8';

vacuum analyze rlis_streets;

--1) create table to hold osm streets
drop table if exists osm_sts_staging cascade;
create table osm_sts_staging (
	id serial primary key,
	geom geometry,
	access text,
	bridge text,
	descriptn text, --to be renamed 'description'
	highway text,
	layer int,
	name text,
	service text,
	surface text,
	tunnel text,
	--fields below are for staging for name expansion
	st_prefix text,
	st_name text,
	st_type text,
	st_direction text
);


--2) Populate osm streets staging table with rlis streets data and translate
--rlis attributes into osm tags
insert into osm_sts_staging (geom, st_prefix, st_name, st_type, st_direction, 
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
		--convert street basename into titlecase (in rlis street names are all caps)
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
		--expnad street direction suffix
		case when direction ilike 'N' then 'North'
			when direction ilike 'NB' then 'Northbound'
			when direction ilike 'E' then 'East'
			when direction ilike 'EB' then 'Eastbound'
			when direction ilike 'S' then 'South'
			when direction ilike 'SB' then 'Southbound'
			when direction ilike 'W' then 'West'
			when direction ilike 'WB' then 'Westbound'
			else null end,
		--convert rlis street to type to osm 'highway' values, metadata on rlis street 
		--type is here: http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=556#
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
		--use rlis 'type' to get values for osm tag 'service'
		case when rs.type in (1600) then 'alley'
			when rs.type in (1750, 1850) then 'driveway'
			else null end,
		--get osm 'access' values (permissions) from rlis 'type'
		case when rs.type in (1700, 1740, 1750, 1760, 1800, 1850) then 'private'
			when rs.type in (5402) then 'no'
			else null end,
		--get osm 'surface' values from rlis 'type'
		case when rs.type in (2000) then 'unpaved'
			else null end,
		--get osm 'layer' values, ground level 1 in rlis, but 0 for osm
		case when f_zlev = t_zlev then
				--if the layer is ground level 'layer' is null
				case when f_zlev = 1 then null 
					when f_zlev > 0 then f_zlev - 1
					when f_zlev < 0 then f_zlev end
			else
				case when f_zlev > 0 and t_zlev < 0 then t_zlev
					when f_zlev > 0 and t_zlev > 0 then greatest(f_zlev, t_zlev) - 1
					when f_zlev < 0 and t_zlev < 0 then least(f_zlev, t_zlev)
					when f_zlev < 0 and t_zlev > 0 then f_zlev end
			end
	from rlis_streets rs;


--2) Add bridge and tunnel tags based on the layer value
drop index if exists layer_ix cascade;
create index layer_ix on osm_sts_staging using BTREE (layer);

vacuum analyze osm_sts_staging;

update osm_sts_staging set bridge = 'yes'
	where layer > 0;

update osm_sts_staging set tunnel = 'yes'
	where layer < 0;


--3) Expand abbreviations that are within the street basename
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Av[e]?(-|\s|$)', '\1Avenue\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Blvd(-|\s|$)', '\1Boulevard\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Brg(-|\s|$)', '\1Bridge\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Ct(-|\s|$)', '\1Court\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Dr(-|\s|$)', '\1Drive\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Fwy(-|\s|$)', '\1Freeway\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Pkwy(-|\s|$)', '\1Parkway\2 ', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Pl(-|\s|$)', '\1Place\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Rd(-|\s|$)', '\1Road\2 ', 'g');
--St--> Street (will not occur at beginning of a st_name)
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)St(-|\s|$)', '\1Street\2 ', 'g');

--Expand other abbreviated parts of street basename
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Cc(-|\s|$)', '\1Community College\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Co(-|\s|$)', '\1County\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Jr(-|\s|$)', '\1Junior\2', 'g');
--Mt at beginning of name is 'Mount' later in name is 'Mountain'
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|-|-\s)Mt(\s)', '\1Mount\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Mt(-|\s|$)', '\1Mountain\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Nfd(-|\s|$)', '\1National Forest Development Road\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(\s)Tc(-|\s|$)', '\1Transit Center\2', 'g');
--St--> Saint (will only occur at the beginning of a street name)
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|-|-\s)(Mt\s|Mount\s|Old\s)?St[.]?(\s)', '\1\2Saint\3', 'g');
update osm_sts_staging set st_name = 
	regexp_replace(st_name, '(^|\s|-)Us(-|\s|$)', '\1United States\2', 'g');

--special case grammar fixes and name expansions
update osm_sts_staging set st_name = 
	--the '~' operator does a posix regular expression comparison between strings
	case when st_name ~ '.*(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$).*'
	then format_titlecase(regexp_replace(st_name, 
		'(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3', 'g'))
	else st_name end;

update osm_sts_staging set st_name = 
	case when st_name ~ '.*(^|\s|-)Ft\sOf\s.*' then 
		case when st_name ~ '.*(^|\s|-)Holladay(-|\s|$).*'
			then regexp_replace(st_name, 'Ft\sOf\sN', 'Foot of North', 'g')
		when st_name ~ '.*(^|\s|-)(Madison|Marion)(-|\s|$).*'
			then regexp_replace(st_name, 'Ft\sOf\sSe', 'Foot of Southeast', 'g')
		else st_name end
	else st_name end;

--more special case name expansions
--for these an index is created and matches are made on the full name of the
--field to decrease run time of script
drop index if exists st_name_ix cascade;
create index st_name_ix on osm_sts_staging using BTREE (st_name);

vacuum analyze osm_sts_staging;

update osm_sts_staging set st_name = 'Bonneville Power Administration'
	where st_name = 'Bpa';
update osm_sts_staging set st_name = 'JQ Adams'
	where st_name = 'Jq Adams';
update osm_sts_staging set st_name = 'Sunnyside Hospital-Mount Scott Medical Transit Center'
	where st_name = 'Sunnyside Hosp-Mount Scott Med Transit Center';


--4) Now that abbreviations in street names have been expanded concatenate their parts
--concat strategy via http://www.laudatio.com/wordpress/2009/04/01/a-better-concat-for-postgresql/
update osm_sts_staging set 
	name = array_to_string(array[st_prefix, st_name, sT_type, st_direction], ' ')
	where highway != 'motorway_link' 
		or highway is null;

--motorway_link's will have descriptions rather than names via osm convention
--source: http://wiki.openstreetmap.org/wiki/Link_%28highway%29
update osm_sts_staging set 
	descriptn = array_to_string(array[st_prefix, st_name, st_type, st_direction], ' ')
	where highway = 'motorway_link';


--5) Merge contiguous segment that have the same values for all attributes to match, osm 
--geometry segmentation, this requires the creation of a new table
drop table if exists osm_streets cascade;
create table osm_streets with oids as
	--st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or multi-polygons) into its
	--individual component parts and creates and entry in the table for each of those parts
	select (ST_Dump(geom)).geom as geom, access, bridge, 
		descriptn, highway, layer, name, service, surface, tunnel
	--st_union merges all the grouped features into a single geometry collection and st_linemerege makes 
	--connected segments into single unified lines where possible
	from (select ST_LineMerge(ST_Union(geom)) as geom, access, bridge, 
				descriptn, highway, layer::text, name, service, surface, tunnel
			from osm_sts_staging 
			group by access, bridge, descriptn, highway, layer, 
				name, service, surface, tunnel) as unioned_streets;

reset client_encoding;