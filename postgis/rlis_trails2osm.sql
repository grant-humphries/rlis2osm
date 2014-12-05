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
	bicycle text,
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
	select geom,
		--decommissioned trails have their 'highway' values moved here
		case when status ~* 'Decommissioned' then 'flag'
			else null end,
		--access permissions
		case when status ~* 'Restricted' then 'license'
			when status ~* 'Restricted_Private' then 'private'
			when status ~* 'Unknown' then 'unknown'
			else null end,
		--alternate name of trail
		format_titlecase(sharedname),
		--bicycle permissions
		case when roadbike ~* 'No' then 'no'
			when (roadbike ~* 'Yes' and width not in ('1-5', '5 ft')
				and trlsurface in ('Hard Surface', 'Decking')) 
				or onstrbike ~* 'Yes' then 'designated'
			when roadbike ~* 'Yes' then 'yes'
			else null end,
		--trails under construction will have their 'highway' values moved here
		case when status ~* 'Under construction' then 'flag'
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
		case when status ~* 'Open_Fee' then 'yes'
			else null end,
		--pedestrian permissions
		case when hike ~* 'No' then 'no'
			when hike ~* 'Yes' then 'designated' 
			else null end,
		--trail type
		case when trlsurface ~* 'Stairs' then 'steps' 
			when onstrbike ~* 'Yes' then 'road'
			--any trail with two or more designated uses is a path
			when (hike ~* 'Yes' and roadbike ~* 'Yes' 
					and trlsurface in ('Hard Surface', 'Decking') 
					and width not in ('1-5', '5 ft'))
				or (hike ~* 'Yes' and mtnbike ~* 'Yes')
				or (hike ~* 'Yes' and equestrian ~* 'Yes')
				or (roadbike ~* 'Yes' and equestrian ~* 'Yes')
				or (mtnbike ~* 'Yes' and equestrian ~* 'Yes') then 'path'
			when roadbike ~* 'Yes' 
				and trlsurface in ('Hard Surface', 'Decking')
				and width not in ('1-5', '5 ft') then 'cycleway'
			when mtnbike ~* 'Yes' then 'path'
			when equestrian ~* 'Yes' then 'bridleway'
			else 'footway' end,
		--equestrian permissions
		case when equestrian ~* 'No' then 'no'
			when equestrian ~* 'Yes' then 'designated'
			else null end,
		--mountain bike permissions
		case when mtnbike ~* 'No' then 'no'
			when mtnbike ~* 'Yes' then 'designated'
			else null end,
		--primary trail name
		format_titlecase(trailname),
		--managing agency
		case when agencyname ~* 'Unknown' then null
			else format_titlecase(agencyname) end,
		--proposed trails have their 'highway' values moved here
		case when status ~* 'Planned' then 'flag'
			else null end,
		--rlis system name, these may eventually be used to create relations, but for now
		--don't include this attribute if it is identical one of the trails other names
		case when systemname ~* trailname 
			or systemname ~* sharedname then null
			else format_titlecase(systemname) end,
		--trail surface
		case when trlsurface ~* 'Chunk Wood' then 'woodchips'
			when trlsurface ~* 'Decking' then 'wood'
			when trlsurface ~* 'Hard Surface' then 'paved'
			when trlsurface ~* 'Imported Material' then 'compacted'
			when trlsurface ~* 'Native Material' then 'ground'
			when trlsurface ~* 'Snow' then 'snow'
			else null end,
		--accessibility status
		case when accessible ~* 'Accessible' then 'yes'
			when accessible ~* 'Not Accessible' then 'no'
			else null end
	from rlis_trails
	where (status != 'Conceptual' or status is null)
		and (trlsurface != 'Water' or trlsurface is null);


--3) Clean-up issues that couldn't be handled on the initial insert

--add index to speed matching below
drop index if exists highway_ix cascade;
create index highway_ix on osm_trls_staging using BTREE (highway);

vacuum analyze osm_trls_staging;

--highway type 'footway' implies foot permissions, it's redundant to have this
--information in the 'foot' tag as well, same goes for 'cycleway' and 'bridleway'
update osm_trls_staging set foot = null
	where highway = 'footway';

update osm_trls_staging set bicycle = null
	where highway = 'cycleway';

update osm_trls_staging set horse = null
	where highway = 'bridleway';

--drop highway index as that field is about to be modified and the index is no longer
--going to be utilized
drop index if exists highway_ix cascade;

--add index to speed matching
drop index if exists abndnd_hwy_ix cascade;
create index abndnd_hwy_ix on osm_trls_staging using BTREE (abndnd_hwy);

drop index if exists cnstrctn_ix cascade;
create index cnstrctn_ix on osm_trls_staging using BTREE (cnstrctn);

drop index if exists proposed_ix cascade;
create index proposed_ix on osm_trls_staging using BTREE (proposed);

--Move highway values into appropriate column for under construction, proposed 
--and abandoned features
update osm_trls_staging 
	set abndnd_hwy = highway, highway = null 
	where abndnd_hwy is not null;

update osm_trls_staging 
	set cnstrctn = highway, highway = 'construction' 
	where cnstrctn is not null;

update osm_trls_staging 
	set proposed = highway, highway = 'proposed' 
	where proposed is not null;


--4) Expand any abbreviations and properly format strings in the name, r_sysname, 
--alt_name, and operator fields

--a) 'name' (aka trailname)

--remove any periods (.) in trailname 
update osm_trls_staging set name = replace(name, '.', '');

--expand street prefixes in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)N(\s)', '\1North\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Ne(\s)', '\1Northeast\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)E(\s)', '\1East\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Se(\s)', '\1Southeast\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)S(\s)', '\1South\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Sw(\s)', '\1Southwest\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)W(\s)', '\1West\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Nw(\s)', '\1Northwest\2', 'gi');

update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Nb(-|\s|$)', '\1Northbound\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Eb(-|\s|$)', '\1Eastbound\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Sb(-|\s|$)', '\1Southbound\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Wb(-|\s|$)', '\1Westbound\2', 'gi');

--expand street types in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ave(-|\s|$)', '\1Avenue\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Blvd(-|\s|$)', '\1Boulevard\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Cir(-|\s|$)', '\1Circle\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s|/)Ct(-|\s|$)', '\1Court\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Dr(-|\s|$|/)', '\1Drive\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ln(-|\s|$)', '\1Lane\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Lp(-|\s|$)', '\1Loop\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Pkwy(-|\s|$)', '\1Parkway\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Pl(-|\s|$)', '\1Place\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Rd(-|\s|$)', '\1Road\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Sq(-|\s|$)', '\1Square\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)St(-|\s|$)', '\1Street\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ter[r]?(-|\s|$)', '\1Terrace\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Wy(-|\s|$)', '\1Way\2', 'gi');

--expand other abbreviations in trailname
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Assn(-|\s|$)', '\1Association\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Bpa(-|\s|$)', '\1Bonneville Power Administration\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Es(-|\s|$)', '\1Elementary School\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Hmwrs(-|\s|$)', '\1Homeowners\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Hoa(-|\s|$)', '\1Homeowners Association\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Jr(-|\s|$)', '\1Junior\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Max(-|\s|$)', '\1Metropolitan Area Express\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Ms(-|\s|$)', '\1Middle School\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Mt(-|\s|$)', '\1Mount\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Ped(-|\s|$)', '\1Pedestrian\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|-\s|-)St(\s)', '\1Saint\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Tc(-|\s|$)', '\1Transit Center\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Us(\s)', '\1United States\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(^|\s|-)Va(-|\s|$)', '\1Veteran Affairs\2', 'gi');

--convert transitional words in trail names to lowercase
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)And(\s)', '\1and\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)At(\s)', '\1at\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)Of(\s)', '\1of\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)On(\s)', '\1on\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)The(\s)', '\1the\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)To(\s)', '\1to\2', 'gi');
update osm_trls_staging set name = 
	regexp_replace(name, '(\s)With(\s)', '\1with\2', 'gi');

--special cases, since these are not common an index is being added to 'name' field
--and matches are being made on the full value to increase speed
drop index if exists name_ix cascade;
create index name_ix on osm_trls_staging using BTREE (name);

vacuum analyze osm_trls_staging;

update osm_trls_staging set name = 'Bureau of Environmental Services Water Quality Control Lab Trail'
	where name = 'Bes Water Quality Control Lab Trail';
update osm_trls_staging set name = 'Fanno Creek Trail at Oregon Electric Right of Way'
	where name = 'Fanno Creek Trail at Oregon Electric ROW';
update osm_trls_staging set name = 'Fulton Community Center Driveway'
	where name = 'Fulton Cc Driveway';
update osm_trls_staging set name = 'Howard M Terpenning Recreation Complex Trails - Connector'
	where name = 'HM Terpenning Recreation Complex Trails - Connector';
update osm_trls_staging set name = 'Shorenstein Properties Limited Liability Company Connector'
	where name = 'Shorenstein Properties Llc Connector';
update osm_trls_staging set name = 'Mt Hood Community College Driveway - Kane Dr Connector'
	where name = 'Mount Hood Cc Driveway - Kane Drive Connector';

--unknown abbreviation, switch back to caps
update osm_trls_staging set name = 'CAT Road (Retired)'
	where name = 'Cat Road (Retired)';
update osm_trls_staging set name = 'FAOF Canberra Trail'
	where name = 'Faof Canberra Trail';
update osm_trls_staging set name = 'TBBV Path'
	where name = 'Tbbv Path';

--typo fixes
update osm_trls_staging set name = 'Andrea Street - Moccasin Connector'
	where name = 'Andrea Street - Mo Ccasin Connector';
update osm_trls_staging set name = 'West Union Road - 151st Place Connector'
	where name = 'West Unioin Road - 151st Place Connector';


--b) 'alt_name' (aka sharedname)

--remove periods (.)
update osm_trls_staging set alt_name = replace(alt_name, '.', '');

--expand abbreviations
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(\s)Ave(-|\s|$)', '\1Avenue\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(\s)Ln(-|\s|$)', '\1Lane\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(^|\s|-)Max(-|\s|$)', '\1Metropolitan Area Express\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(^|\s|-)Mt(-|\s|$)', '\1Mount\2', 'gi');	
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(^|\s|-)Sw(\s)', '\1Southwest\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(^|\s|-)Wes(-|\s|$)', '\1Westside Express Service\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(^|\s|-)Thprd(-|\s|$)', '\1Tualatin Hills Park & Recreation District\2', 'gi');

--grammar fixes
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(\s)And(\s)', '\1and\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(\s)The(\s)', '\1the\2', 'gi');
update osm_trls_staging set alt_name = 
	regexp_replace(alt_name, '(\s)To(\s)', '\1to\2', 'gi');

--special cases, use index and match full name
drop index if exists alt_name_ix cascade;
create index alt_name_ix on osm_trls_staging using BTREE (alt_name);

vacuum analyze osm_trls_staging;

update osm_trls_staging set alt_name = 'Tualatin Valley Water District Water Treatment Plant Trails'
	where alt_name ~* 'TVWD Water Treatment Plant Trails';


--c) 'r_sysname' (aka systemname)

--remove periods (.)
update osm_trls_staging set r_sysname = replace(r_sysname, '.', '');

--expand street prefixes
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|-\s|-)N(\s)', '\1North\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Ne(\s)', '\1Northeast\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Nw(\s)', '\1Northwest\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Se(\s)', '\1Southeast\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Sw(\s)', '\1Southwest\2', 'gi');

--expand street types
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Ave(-|\s|$)', '\1Avenue\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Blvd(-|\s|$)', '\1Boulevard\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Ct(-|\s|$)', '\1Court\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Dr(-|\s|$)', '\1Drive\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Ln(-|\s|$)', '\1Lane\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Pl(-|\s|$)', '\1Place\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Rd(-|\s|$)', '\1Road\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)St(-|\s|$)', '\1Street\2', 'gi');

--expand other abbreviations
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Assn(-|\s|$)', '\1Association\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Es[l]?(-|\s|$)', '\1Elementary School\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Hoa(-|\s|$)', '\1Homeowners Association\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Hmwrs(\s)', '\1Homeowners\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Max(-|\s|$)', '\1Metropolitan Area Express\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Ms(-|\s|$)', '\1Middle School\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Mt(\s)', '\1Mount\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Psu(-|\s|$)', '\1Portland State University\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Rr(-|\s|$)', '\1Railroad\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|-\s|-)St(\s)', '\1Saint\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)Thprd(-|\s|$)', '\1Tualatin Hills Park & Recreation District\2', 'gi');

--special case expansions
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(^|\s|-)HM(\s)', '\1Howard M\2', 'gi');

--grammar fixes
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)At(\s)', '\1at\2', 'gi');
update osm_trls_staging set r_sysname = 
	--second 'd' is for typo fix
	regexp_replace(r_sysname, '(\s)And[d]?(\s)', '\1and\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)Of(\s)', '\1of\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)On(\s)', '\1on\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)The(\s)', '\1the\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)To(\s)', '\1to\2', 'gi');
update osm_trls_staging set r_sysname = 
	regexp_replace(r_sysname, '(\s)With(\s)', '\1with\2', 'gi');

--special cases, use index and match full name
drop index if exists r_sysname_ix cascade;
create index r_sysname_ix on osm_trls_staging using BTREE (r_sysname);

vacuum analyze osm_trls_staging;

update osm_trls_staging set r_sysname = 'Archibald M Kennedy Park Trails'
	where r_sysname = 'AM Kennedy Park Trails';
update osm_trls_staging set r_sysname = 'Latter Day Saints Trails'
	where r_sysname = 'Lds Trails';
update osm_trls_staging set r_sysname = 'Orenco Gardens Limited Liability Company Park Trails'
	where r_sysname = 'Orenco Gardens Llc Park Trails';
update osm_trls_staging set r_sysname = 'Pacific Grove #4 Homeowners Association Trails'
	where r_sysname = 'Pacific Grove No 4 Homeowners Association Trails';
update osm_trls_staging set r_sysname = 'Renaissance at Peterkort Woods Homeowners Trails'
	where r_sysname = 'Renaissance at Pkw Homeowners Trails';
update osm_trls_staging set r_sysname = 'Proposed Regional Southwest Corridor Connector'
	where r_sysname = 'Proposed Regional Swc Connector';
update osm_trls_staging set r_sysname = 'Tualatin Valley Water District Water Treatment Plant Trails'
	where r_sysname = 'Tvwd Water Treatment Plant Trails';
update osm_trls_staging set r_sysname = 'Ulin J Hamby Park Trails'
	where r_sysname = 'Uj Hamby Park Trails';
update osm_trls_staging set r_sysname = 'Washington State University Campus Trails'
	where r_sysname = 'Wsu Campus Trails';

--unknown abbreviation, switch back to caps
update osm_trls_staging set r_sysname = 'PBH Incorporated Trails'
	where r_sysname = 'Pbh Inc Trails';

--typo fixes
update osm_trls_staging set r_sysname = 'Chieftain Dakota Greenway Trails'
	where r_sysname = 'Chiefain Dakota Greenway Trails';
update osm_trls_staging set r_sysname = 'Tanasbourne Villas Trail'
	where r_sysname = 'Tanasbource Villas Trail';
update osm_trls_staging set r_sysname = 'Southwest Portland Willamette Greenway Trail'
	where r_sysname = 'Southwest Portland Wilamette Greenway Trail';


--d) 'operator' (aka agencyname)

--expand abbreviations
update osm_trls_staging set operator = 
	regexp_replace(operator, '(^|\s|-)Us(-|\s|$)', '\1Unites States\2', 'gi');

--grammar fixes
update osm_trls_staging set operator = 
	regexp_replace(operator, '(\s)And(\s)', '\1and\2', 'gi');
update osm_trls_staging set operator = 
	regexp_replace(operator, '(\s)Of(\s)', '\1of\2', 'gi');
update osm_trls_staging set operator = 
	regexp_replace(operator, '(^|\s|-)Trimet(-|\s|$)', '\1TriMet\2', 'gi');


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
			from osm_trls_staging
			group by abndnd_hwy, access, alt_name, bicycle, cnstrctn, est_width, fee, 
			foot, highway, horse, mtb, name, operator, proposed, r_sysname, surface, 
			wheelchair) as unioned_trails;

reset client_encoding;