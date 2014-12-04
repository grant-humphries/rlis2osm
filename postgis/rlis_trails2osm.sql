--RLIS Streets to OSM Attribute Conversion
--Grant Humphries for TriMet, 2012-2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This is a setting to make things run properly in the windows command prompt
set client_encoding to 'UTF8';

vacuum analyze rlis_trails;

--1) Create table to hold osm trails
drop table if exists osm_trls_staging cascade;
create table osm_trls_staging (
	id serial primary key,
	geom geometry,
	abndnd_hwy text, --to be renamed abandoned:highway
	access text,
	alt_name text,
	bicycle text
	cnstrctn text, --to be renamed construction
	est_width text,
	fee text,
	foot text,
	highway text,
	horse text,
	mtb text,
	name text,
	operator text,
	proposed text,
	r_sysname text, --to be renamed RLIS:systemname
	surface text,
	wheelchair text
);


--2) Populate osm trails staging table with rlis trails data and translate rlis attributes 
--into osm tags.  Metadata on the rlis trails attributes can be found here:
--http://rlisdiscovery.oregonmetro.gov/?action=viewDetail&layerID=2404#
insert into osm_trls_staging (geom, abndnd_hwy, access, alt_name, bicycle, cnstrctn,
		est_width, fee, foot, highway, horse, mtb, name, operator, proposed, r_sysname,
		surface, wheelchair)
	select rs.geom,
		--decommissioned trails have their 'highway' values moved here
		case when status ilike 'Decommissioned' then 'flag'
			else null end,
		--access permissions
		case when status ilike 'Restricted' then 'license'
			when status ilike 'Restricted_Private' then 'private'
			when status ilike 'Unknown' then 'unknown'
			else null end,
		--alternate name of trail
		format_titlecase(sharedname),
		--bicycle permissions
		case when roadbike ilike 'No' then 'no'
			when (roadbike ilike 'Yes' and width not in ('1-5', '5 ft')
				and trlsurface in ('Hard Surface', 'Decking') 
				or onstrbike ilike 'Yes' then 'designated'
			when roadbike ilike 'Yes' then 'yes'
			else null end,
		--trails under construction will have their 'highway' values moved here
		case when status ilike 'Under construction' then 'flag'
			else null end,
		--estimated trail width, rlis widths are in feet, osm in meters, to get the
		--meters value I took the average of the interval and rounded to the nearest
		--half meter
		case when width = '1-5' then '1.0'
			when width = '5 ft' then '1.5'
			when width = '6-9' then '2.5'
			when width = '10-14' then '3.5'
			when width = '15+' then '5.0'
			else null end,
		--trail fee information
		case when status ilike 'Open_Fee' then 'yes'
			else null end,
		--pedestrian permissions
		case when hike ilike 'No' then 'no'
			when hike ilike 'Yes' then 'designated' 
			else null end,
		--trail type
		case when trlsurface ilike 'Stairs' then 'steps' 
			when onstrbike ilike 'Yes' then 'road'
			--any trail with two or more designated uses is a path
			when (hike ilike 'Yes' and roadbike ilike 'Yes' 
					and trlsurface in ('Hard Surface', 'Decking') 
					and width not in ('1-5', '5 ft'))
				or (hike ilike 'Yes' and mtnbike ilike 'Yes')
				or (hike ilike 'Yes' and equestrian ilike 'Yes')
				or (roadbike ilike 'Yes' and equestrian ilike 'Yes')
				or (mtnbike ilike 'Yes' and equestrian ilike 'Yes') then 'path'
			when roadbike ilike 'Yes' 
				and trlsurface in ('Hard Surface', 'Decking')
				and width not in ('1-5', '5 ft') then 'cycleway'
			when mtnbike ilike 'Yes' then 'path'
			when equestrian ilike 'Yes' then 'bridleway'
			else 'footway' end,
		--equestrian permissions
		case when equestrian ilike 'No' then 'no'
			when equestrian ilike 'Yes' then 'designated'
			else null end,
		--mountain bike permissions
		case when mtnbike ilike 'No' then 'no'
			when mtnbike ilike 'Yes' then 'designated'
			else null end,
		--primary trail name
		format_titlecase(trailname),
		--managing agency
		case when agencyname ilike 'Unknown' then null
			else format_titlecase(agencyname) end,
		--proposed trails have their 'highway' values moved here
		case when status ilike 'Planned' then 'flag'
			else null end,
		--rlis system name, these may eventually be used to create relations, but for now
		--don't include this attribute if it is identical one of the trails other names
		case when systemname ilike trailname 
			or systemname ilike sharedname then null
			else format_titlecase(systemname) end,
		--trail surface
		case when trlsurface ilike 'Chunk Wood' then 'woodchips'
			when trlsurface ilike 'Decking' then 'wood'
			when trlsurface ilike 'Hard Surface' then 'paved'
			when trlsurface ilike 'Imported Material' then 'compacted'
			when trlsurface ilike 'Native Material' then 'ground'
			when trlsurface ilike 'Snow' then 'snow'
			else null end,
		--accessibility status
		case when accessible ilike 'Accessible' then 'yes'
			when accessible ilike 'Not Accessible' then 'no'
			else null end
	from rlis_trails
	where (status != 'Conceptual' or status is null)
		and (trlsurface != 'Water' or trlsurface is null);


--3) Clean-up issues that couldn't be handled on the initial insert

-use indexes here???

--highway type 'footway' implies foot permissions, it's redundant to have this
--information in the 'foot' tag as well, same goes for 'cycleway' and 'bridleway'
update osm_trls_staging set foot to null
	where highway = 'footway';

update osm_trls_staging set bicycle to null
	where highway = 'cycleway';

update osm_trls_staging set horse to null
	where highway = 'bridleway';

--Move highway values into appropriate column for under construction, proposed 
--and abandoned features
update osm_trls_staging 
	set abndnd_hwy = highway, highway to null 
	where abndnd_hwy is not null;

update osm_trls_staging 
	set cnstrctn = highway, highway = 'construction' 
	where cnstrctn is not null;

update osm_trls_staging 
	set proposed = highway, highway = 'proposed' 
	where proposed is not null;





--4) Remove Abbreviations and unwanted characters and descriptors from name, systemname, 
--alt_name, and operator fields

--remove any periods in trailname 
update osm_trails set name = replace(name, '.', '');

--expand street prefixes in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)N(\s)', '\1North\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Ne(\s)', '\1Northeast\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)E(\s)', '\1East\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Se(\s)', '\1Southeast\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)S(\s)', '\1South\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Sw(\s)', '\1Southwest\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)W(\s)', '\1West\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Nw(\s)', '\1Northwest\2', 'g');

update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Nb(-|\s|$)', '\1Northbound\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Eb(-|\s|$)', '\1Eastbound\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Sb(-|\s|$)', '\1Southbound\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Wb(-|\s|$)', '\1Westbound\2', 'g');

--expand street types in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ave(-|\s|$)', '\1Avenue\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Blvd(-|\s|$)', '\1Boulevard\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Cir(-|\s|$)', '\1Circle\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ct(-|\s|$)', '\1Court\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Dr(-|\s|$)', '\1Drive\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ln(-|\s|$)', '\1Lane\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Lp(-|\s|$)', '\1Loop\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Pkwy(-|\s|$)', '\1Parkway\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Pl(-|\s|$)', '\1Place\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Rd(-|\s|$)', '\1Road\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Sq(-|\s|$)', '\1Square\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)St(-|\s|$)', '\1Street\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ter[r]?(-|\s|$)', '\1Terrace\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Wy(-|\s|$)', '\1Way\2', 'g');

--expand other abbreviations in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Assn(-|\s|$)', '\1Association\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Es(-|\s|$)', '\1Elementary School\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Hmwrs(-|\s|$)', '\1Homeowners\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Hoa(-|\s|$)', '\1Homeowners Association\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Jr(-|\s|$)', '\1Junior\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Llc(-|\s|$)', '\1Limited Liability Company\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ms(-|\s|$)', '\1Middle School\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Mt(-|\s|$)', '\1Mount\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Ped(-|\s|$)', '\1Pedestrian\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)St(\s)', '\1Saint\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Tc(-|\s|$)', '\1Tranist Center\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Us(\s)', '\1United States\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Va(-|\s|$)', '\1Veteran Affairs\2', 'g');

--expand special cases in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Bes(-|\s|$)', '\1Bureau of Environmental Services\2', 'g');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Bpa(-|\s|$)', '\1Bonneville Power Administration\2', 'g');



--Various grammar fixes *not* related to abbreviations
update osm_trails set name = replace(name, ' And ', ' and ');
update osm_trails set name = replace(name, ' At ', ' at ');
update osm_trails set name = replace(name, ' Of ', ' of ');
update osm_trails set name = replace(name, ' On ', ' on ');
update osm_trails set name = replace(name, ' The ', ' the ');
update osm_trails set name = replace(name, ' To ', ' to ');
update osm_trails set name = replace(name, ' With ', ' with ');





update osm_trails set name = replace(name, 'Fulton Cc', 'Fulton Community Center');
update osm_trails set name = replace(name, 'HM', 'Howard M');

--Unknown abbreviations switched back to caps
update osm_trails set name = replace(name, 'Tbbv', 'TBBV');

--MAX is most common name, most folks don't know Metropolitan Area eXpress
update osm_trails set name = replace(name, 'Max ', 'MAX ');




















--b) Remove abbreviations from "alt_name"
--Removes extra spaces
update osm_trails set alt_name = replace(alt_name, '  ', ' ');

drop index if exists alt_name_ix cascade;
create index alt_name_ix ON osm_trails using BTREE (alt_name);

--grammar fixes
update osm_trails set alt_name = replace(alt_name, ' To ', ' to ');
update osm_trails set alt_name = replace(alt_name, ' The ', ' the ');
update osm_trails set alt_name = replace(alt_name, ' And ', ' and ');

--abbreviation expansions
update osm_trails set alt_name = replace(alt_name, 'Mt ', 'Mount ');
update osm_trails set alt_name = replace(alt_name, 'SW ', 'Southwest ');
update osm_trails set alt_name = replace(alt_name, 'Ave ', 'Avenue ');


--c) Remove abbreviations from "systemname"
--Convert to Camel Case
update osm_trails set systemname = format_titlecase(systemname);

drop index if exists systemname_ix cascade;
create index systemname_ix ON osm_trails using BTREE (systemname);

--Removes periods and extra spaces
update osm_trails set systemname = replace(systemname, '.', '');
update osm_trails set systemname = replace(systemname, '  ', ' ');

--grammar fixes
update osm_trails set systemname = replace(systemname, ' Of ', ' of ');
update osm_trails set systemname = replace(systemname, ' To ', ' to ');
update osm_trails set systemname = replace(systemname, ' On ', ' on ');
update osm_trails set systemname = replace(systemname, ' The ', ' the ');
update osm_trails set systemname = replace(systemname, ' At ', ' at ');
update osm_trails set systemname = replace(systemname, ' And ', ' and ');

--Street prefixes
update osm_trails set systemname = replace(systemname, 'Nw ', 'Northwest ');
update osm_trails set systemname = replace(systemname, 'Se ', 'Southeast ');
update osm_trails set systemname = replace(systemname, 'Sw ', 'Southwest ');

--Street sufixes that are comprised of letter combination that *don't* appear in other words
update osm_trails set systemname = replace(systemname, 'Rd', 'Road');
update osm_trails set systemname = replace(systemname, 'Hwy', 'Highway');

--Street sufixes that are comprised of letter combination that appear in other words
update osm_trails set systemname = replace(systemname, 'Ave', 'Avenue') where right(systemname, 3) = 'Ave';
update osm_trails set systemname = replace(systemname, 'Ave ', 'Avenue ');

--Other abbreviation extensions
update osm_trails set systemname = replace(systemname, 'Mt ', 'Mount ');
update osm_trails set systemname = replace(systemname, 'St ', 'Saint ');
update osm_trails set systemname = replace(systemname, 'Ped ', 'Pedestrian ');
update osm_trails set systemname = replace(systemname, 'Assn', 'Association');
update osm_trails set systemname = replace(systemname, 'Hmwrs', 'Homeowners');
update osm_trails set systemname = replace(systemname, ' Hoa', ' Homeowners Association');
update osm_trails set systemname = replace(systemname, ' Ms', ' Middle School');
update osm_trails set systemname = replace(systemname, 'Es ', 'Elementary School ');
update osm_trails set systemname = replace(systemname, 'Lds', 'Latter Day Saints');
update osm_trails set systemname = replace(systemname, ' No ', ' #');
update osm_trails set systemname = replace(systemname, 'Inc ', 'Incorporated ');

--Special cases
update osm_trails set systemname = replace(systemname, 'AM', 'Archibald M.');
update osm_trails set systemname = replace(systemname, 'HM', 'Howard M.');
update osm_trails set systemname = replace(systemname, 'Uj Hamby', 'Ulin J. Hamby');
update osm_trails set systemname = replace(systemname, 'Pkw', 'Peterkort Woods');
update osm_trails set systemname = replace(systemname, 'Thprd', 'Tualatin Hills Park & Recreation District');
update osm_trails set systemname = replace(systemname, 'Tvwd', 'Tualatin Valley Water District');
update osm_trails set systemname = replace(systemname, 'Pcc', 'Portland Community College');
update osm_trails set systemname = replace(systemname, 'Psu', 'Portland State University');
update osm_trails set systemname = replace(systemname, 'Wsu', 'Washington State University');

--Typo fixes
update osm_trails set systemname = replace(systemname, 'Ccccccc', '');
update osm_trails set systemname = replace(systemname, 'Chiefain', 'Chieftain');
update osm_trails set systemname = replace(systemname, 'Esl ', 'Elementary School ');
update osm_trails set systemname = replace(systemname, 'Tanasbource', 'Tanasbourne');
update osm_trails set systemname = replace(systemname, 'Wilamette', 'Willamette');
update osm_trails set systemname = replace(systemname, 'Southwest Pedestrian Walkway', 'Southwest Pedestrian Walkways');


--Unknown abbreviations switched back to caps
update osm_trails set systemname = replace(systemname, 'Pbh', 'PBH');

--MAX is most common name, most folks don't know Metropolitan Area eXpress
update osm_trails set systemname = replace(systemname, 'Max ', 'MAX ');



--d) Remove abbreviations from "operator"

--A few minor fixes, everything is already expanded, cameled, etc. for the most part
update osm_trails set operator = replace(operator, 'US', 'United States');
update osm_trails set operator = replace(operator, 'COUNTY', 'County');




--6) Merge contiguous segment that have the same values for all attributes, this requires
--the creation of a new table
drop table if exists osm_trails cascade;
create table osm_trails with oids as
	--st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or 
	--multi-polygons) into its individual component parts and creates and entry in the 
	--table for each of those parts
	select (ST_Dump(geom)).geom as geom, abndnd_hwy, access, alt_name, bicycle, cnstrctn, 
		est_width, fee, foot, highway, horse, mtb, name, operator, proposed, r_sysname,
		surface, wheelchair
	--st_union merges all the grouped features into a single geometry collection and 
	--st_linemerege makes connected segments into single unified lines where possible
	from (select ST_LineMerge(ST_Union(geom)) as geom, abndnd_hwy, access, alt_name, 
				bicycle, cnstrctn, est_width, fee, foot, highway, horse, mtb, name, 
				operator, proposed, r_sysname, surface, wheelchair
			from osm_trails
			group by abndnd_hwy, access, alt_name, bicycle, cnstrctn, est_width, fee, 
			foot, highway, horse, mtb, name, operator, proposed, r_sysname, surface, 
			wheelchair) as unioned_trails;

reset client_encoding;