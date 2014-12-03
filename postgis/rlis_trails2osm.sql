--RLIS Streets to OSM Attribute Conversion
--Grant Humphries for TriMet, 2012-2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This is a setting to make things run properly in the windows command prompt
set client_encoding to 'UTF8';

vacuum analyze rlis_trails;

--1) create temporary table on which to perform the attribute conversions
drop table if exists osm_trls_staging cascade;
create table osm_trls_staging (
	id serial primary key,
	geom geometry,
	abandoned text,
	access text,
	alt_name text,
	bicycle text
	cnstrctn text,  --to be renamed construction
	est_width text,
	fee text,
	foot text,
	highway text,
	hwy_abndnd text, --to be renamed highway:abandoned
	horse text,
	mtb text,
	name text,
	operator text,
	proposed text,
	surface text,
	wheelchair text, 

	systemname text, --to be renamed RLIS:systemname

	--These attributes influence multiple tags and will eventually be dropped, their headings are rlis fields
	status text,
	trlsurface text,
	hike text,
	roadbike text,
	onstrbike text,

	--These attributes are derived from a single rlis field, but fields from which they're derived influence multiple tags and
	--thus are kept in a separate column, the headings here are osm keys


	--These attributes are derived from multiple rlis fields, the logic to determine the values within is below
	--The heading to these columns are osm keys
);


--2) POPULATE osm_sts from rlis_trails
insert into osm_trls_staging (geom, name, systemname, alt_name, access, est_width, wheelchair, mtb, horse, operator, 
		status, trlsurface, hike, roadbike, onstrbike)
	select rs.geom, 
		format_titlecase(trailname),
		format_titlecase(systemname),
		format_titlecase(sharedname), 
		--access permissions
		case when status ilike 'Restricted' then 'license'
			when status ilike 'Restricted_Private' then 'private'
			when status ilike 'Unknown' then 'unknown'


		rs.width, rs.accessible, rs.mtnbike,
	  rs.equestrian, rs.agencyname, rs.status, rs.trlsurface, rs.hike, rs.roadbike, rs.onstrbike
	from rlis_trails rs
	where (status != 'Conceptual' or status is null)
		and (trlsurface != 'Water' or trlsurface is null);

--4) Remove Abbreviations and unwanted characters and descriptors from name, systemname, alt_name, and operator fields



--Add index to speed performance
drop index if exists name_ix cascade;
create index name_ix ON osm_trails using BTREE (name);

--Removes periods and extra spaces
update osm_trails set name = replace(name, '.', '');

--Various grammar fixes *not* related to abbreviations
update osm_trails set name = replace(name, ' And ', ' and ');
update osm_trails set name = replace(name, ' To ', ' to ');
update osm_trails set name = replace(name, ' With ', ' with ');
update osm_trails set name = replace(name, ' Of ', ' of ');
update osm_trails set name = replace(name, ' On ', ' on ');
update osm_trails set name = replace(name, ' The ', ' the ');
update osm_trails set name = replace(name, ' At ', ' at ');
update osm_trails set name = replace(name, ' - Connector', '') where (name LIKE '%Connector%Connector%');

--Street prefixes
update osm_trails set name = replace(name, 'N ', 'North ');
update osm_trails set name = replace(name, 'Ne ', 'Northeast ');
update osm_trails set name = replace(name, 'Nw ', 'Northwest ');
update osm_trails set name = replace(name, 'Se ', 'Southeast ');
update osm_trails set name = replace(name, 'Sw ', 'Southwest ');

--Street sufixes that are comprised of letter combination that *don't* appear in other words
update osm_trails set name = replace(name, 'Rd', 'Road');
update osm_trails set name = replace(name, 'Ct', 'Court');
update osm_trails set name = replace(name, 'Ln', 'Lane');
update osm_trails set name = replace(name, 'Lp', 'Loop');
update osm_trails set name = replace(name, 'Blvd', 'Boulevard');
update osm_trails set name = replace(name, 'Pkwy', 'Parkway');
update osm_trails set name = replace(name, 'Hwy', 'Highway');

--Saint at the beginning of the field, this must be in front the "street" expansion code
update osm_trails set name = replace(name, 'St ', 'Saint ') where left(name, 2) = 'St';

--Street sufixes that are comprised of letter combination that appear in other words
--The first line of code overwrites only abbreviations that appear at the end of a field
--the second line contains a space after the abbreviation so words beginning with these letters won't be modified
update osm_trails set name = replace(name, 'Ave', 'Avenue') where right(name, 3) = 'Ave';
update osm_trails set name = replace(name, 'Ave ', 'Avenue ');
update osm_trails set name = replace(name, 'St', 'Street') where right(name, 2) = 'St';
update osm_trails set name = replace(name, 'St ', 'Street ');
update osm_trails set name = replace(name, 'Pl', 'Place') where right(name, 2) = 'Pl';
update osm_trails set name = replace(name, 'Pl ', 'Place ');
update osm_trails set name = replace(name, 'Dr', 'Drive') where right(name, 2) = 'Dr';
update osm_trails set name = replace(name, 'Dr ', 'Drive ');
update osm_trails set name = replace(name, 'Ter', 'Terrace') where right(name, 3) = 'Ter';
update osm_trails set name = replace(name, 'Ter ', 'Terrace ');
update osm_trails set name = replace(name, 'Terr', 'Terrace') where right(name, 4) = 'Terr';
update osm_trails set name = replace(name, 'Terr ', 'Terrace ');
update osm_trails set name = replace(name, 'Wy', 'Way') where right(name, 2) = 'Wy';
update osm_trails set name = replace(name, 'Wy ', 'Way ');

--Other abbreviation extensions
update osm_trails set name = replace(name, 'Ped ', 'Pedestrian ');
update osm_trails set name = replace(name, 'Tc', 'Transit Center');
update osm_trails set name = replace(name, 'Assn', 'Association');
update osm_trails set name = replace(name, 'Hmwrs', 'Homeowners');
update osm_trails set name = replace(name, 'Mt ', 'Mount ');
update osm_trails set name = replace(name, 'Jr ', 'Junior ');

--Special cases
update osm_trails set name = replace(name, ' Hoa', ' Homeowners Association');
update osm_trails set name = replace(name, 'Bpa ', 'Bonneville Power Administration ');
update osm_trails set name = replace(name, 'Bes ', 'Bureau of Environmental Services ');
update osm_trails set name = replace(name, 'Fulton Cc', 'Fulton Community Center');
update osm_trails set name = replace(name, 'HM', 'Howard M.');

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

--Delete value in "systemname" for trails that where it duplictates the value in "name" or "alt_name"
update osm_trails set systemname = '' 
	where (UPPER(systemname) = UPPER(name) OR UPPER(systemname) = UPPER(alt_name));


--d) Remove abbreviations from "operator"

--These entries don't actually explain who the operator is, thus their removal
update osm_trails set operator = '' 
	where operator = 'Home Owner Association' OR operator = 'Unknown';

--A few minor fixes, everything is already expanded, cameled, etc. for the most part
update osm_trails set operator = replace(operator, 'US', 'United States');
update osm_trails set operator = replace(operator, 'COUNTY', 'County');

--5) Convert Attributes from RLIS to OSM nomenclature
--a) Staight-forward conversions for populated columns

--est_width
update osm_trails set est_width = '1.0' where est_width = '1-5';
update osm_trails set est_width = '2.5' where est_width = '6-9';
update osm_trails set est_width = '2.5' where est_width = '5-10';
update osm_trails set est_width = '3.0' where est_width = '10';
update osm_trails set est_width = '3.5' where est_width = '10-14';
update osm_trails set est_width = '4.5' where est_width = '15+';
update osm_trails set est_width = '' where est_width = 'Unknown';

--wheelchair=*
update osm_trails set wheelchair =  'yes' where wheelchair = 'Accessible';
update osm_trails set wheelchair =  'no' where wheelchair = 'Not Accessible';
update osm_trails set wheelchair =  '' where wheelchair != 'Accessible' AND wheelchair != 'Not Accessible';

--mtb=*
update osm_trails set mtb = 'yes' where mtb = 'Yes';
update osm_trails set mtb = 'no' where mtb = 'No';
update osm_trails set mtb = '' where mtb != 'Yes' AND mtb != 'No';

--horse=*
update osm_trails set horse = 'yes' where horse = 'Yes';
update osm_trails set horse = 'no' where horse = 'No';
update osm_trails set horse = '' where horse != 'Yes' AND horse != 'No';

--b) Staight-forward conversions for empty columns

--Add indices to improve perfromance
drop index if exists status_ix cascade;
create index status_ix ON osm_trails using BTREE (status);

drop index if exists trlsurface_ix cascade;
create index trlsurface_ix ON osm_trails using BTREE (trlsurface);

--access=*
update osm_trails set access = 'license' where status = 'Restricted';
update osm_trails set access = 'unknown' where status = 'Unknown';
update osm_trails set access = 'private' where status = 'Restricted_Private';

--fee=*
update osm_trails set fee = 'yes' where status = 'Open_Fee';

--abandoned=*
--Need to append and "abandoned:" prefix on the highway tags of trails that have this tag
update osm_trails set abandoned = 'yes' where status = 'Decommissioned';

-- surface=*
update osm_trails set surface = 'ground' where trlsurface = 'Native Material';
update osm_trails set surface = 'woodchip' where trlsurface = 'Chunk Wood';
--Comparison of value "Hard Surface" is done in upper case because there are inconsistencies 
--in capitalization of this phrase
update osm_trails set surface = 'paved' where UPPER(trlsurface) = UPPER('Hard Surface');
update osm_trails set surface = 'wood' where trlsurface = 'Decking';
update osm_trails set surface = 'pebblestone' where trlsurface = 'Imported Material';

--c) Straight forward conversions on empty columns that will be over written in some places based on other attributes

drop index if exists hike_ix cascade;
create index hike_ix ON osm_trails using BTREE (hike);

drop index if exists roadbike_ix cascade;
create index roadbike_ix ON osm_trails using BTREE (roadbike);

--foot=*
update osm_trails set foot = 'no' where hike = 'No';
 
--bicycle=*
update osm_trails set bicycle = 'yes' where roadbike = 'Yes';
update osm_trails set bicycle = 'no' where roadbike = 'No';

--d) Complex conversions

--Add indices to improve performance
drop index if exists horse_ix cascade;
create index horse_ix ON osm_trails using BTREE (horse);

drop index if exists onstrbike_ix cascade;
create index onstrbike_ix ON osm_trails using BTREE (onstrbike);

drop index if exists est_width_ix cascade;
create index est_width_ix ON osm_trails using BTREE (est_width);

--highway=*
--First set all entries to highway=footway
update osm_trails set highway = 'footway';

--Multi-Use Paths (MUPs)
update osm_trails set highway = 'path', bicycle = 'designated', foot = 'designated'
   where roadbike = 'Yes' AND hike = 'Yes' AND est_width != '1.0' AND (onstrbike = 'Yes' OR onstrbike = 'No')
   AND (UPPER(trlsurface) = UPPER('Hard Surface') OR trlsurface = 'Decking');

--Bike only paths
update osm_trails set highway = 'cycleway', bicycle = ''
   where roadbike = 'Yes' AND onstrbike = 'Yes' AND est_width != '1.0'
   AND (UPPER(trlsurface) = UPPER('Hard Surface') OR trlsurface = 'Decking') AND hike = 'No';

--Hiking Trails
update osm_trails set highway = 'path', foot = 'designated'
   where hike = 'Yes' AND roadbike = 'No' AND UPPER(trlsurface) != UPPER('Hard Surface') AND horse != 'yes';

--Horseback riding trails
update osm_trails set highway = 'bridleway'
   where horse = 'yes' AND roadbike = 'No' AND UPPER(trlsurface) != UPPER('Hard Surface');
update osm_trails set foot = 'yes' where highway = 'bridleway' AND hike = 'Yes';

--Stairs (this is stored on trlsurface for some reason)
update osm_trails set highway = 'steps', bicycle = '', foot = '' 
   where trlsurface = 'Stairs';

--Move value out of highway column and into another colunm for special cases like construction, proposed and abandoned features
update osm_trails set hwy_abndnd = highway, highway = '' where abandoned = 'yes';
update osm_trails set cnstrctn = highway, highway = 'construction' where status = 'Under construction';
update osm_trails set proposed = highway, highway = 'proposed' where status = 'Planned';

--A footway with a foot=no tag doesn't make sense, I found that this was occuring on trails that require a fee to access
update osm_trails set foot = 'license', access = 'no' where highway = 'footway' AND foot = 'no';


--6) Merge contiguous segment that have the same values for all attributes, this requires the creation of a new table as
--far as I can tell
drop table if exists osm_trails_final cascade;
create table osm_trails_final WITH OIDS AS
	--st_dump is essentially the opposite of 'group by', it unpacks multi-linestings (or multi-polygons) into its
	--individual component parts and creates and entry in the table for each of those parts
	select (ST_Dump(geom)).geom AS geom, name, systemname, alt_name, est_width, wheelchair, mtb,
		horse, operator, access, fee, abandoned, surface, highway, proposed, cnstrctn, hwy_abndnd, 
		foot, bicycle
	--st_union merges all the grouped features into a single geometry collection and st_linemerege makes 
	--connected segments into single unified lines where possible
	from (select ST_LineMerge(ST_Union(geom)) AS geom, name, systemname, alt_name, est_width,
			  wheelchair, mtb, horse, operator, access, fee, abandoned, surface, highway, proposed, 
			  cnstrctn, hwy_abndnd, foot, bicycle 
		  from osm_trails
		  GROUP BY name, systemname, alt_name, est_width, wheelchair, mtb, horse, operator, 
			  access, fee, abandoned, surface, highway, proposed, cnstrctn, hwy_abndnd, foot, 
			  bicycle) as unioned_trails;

--Get rid of the temporary table in which all of the translations were made
drop table if exists osm_trails cascade;

reset client_encoding;