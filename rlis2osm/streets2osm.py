

dir_prefix = {
    'N': 'North',
    'NE': 'Northeast',
    'E': 'East',
    'SE': 'Southeast',
    'S': 'South',
    'SW': 'Southwest',
    'W': 'West',
    'NW': 'Northwest'
}
street_type = {
    'ALY': 'Alley',
    'AVE': 'Avenue',
    'BLVD': 'Boulevard',
    'BRG': 'Bridge',
    'CIR': 'Circle',
    'CORR': 'Corridor',
    'CRST': 'Crest',
    'CT': 'Court',
    'DR': 'Drive',
    'EXPY': 'Expressway',
    'FRTG': 'Frontage Road',
    'FWY': 'Freeway',
    'HTS': 'Heights',
    'HWY': 'Highway',
    'LN': 'Lane',
    'LNDG': 'Landing',
    'PKWY': 'Parkway',
    'PL': 'Place',
    'PT': 'Point',
    'RD': 'Road',
    'RDG': 'Ridge',
    'RR': 'Railroad',
    'SQ': 'Square',
    'ST': 'Street',
    'TER': 'Terrace',
    'TRL': 'Trail',
    'VIA': 'Viaduct',
    'VW': 'View'
}
dir_suffix = {
    'N': 'North',
    'NB': 'Northbound',
    'E': 'East',
    'EB': 'Eastbound',
    'S': 'South',
    'SB': 'Southbound',
    'W': 'West',
    'WB': 'Westbound'
}

(1110, 5101, 5201) then 'motorway'
(1120, 1121, 1122, 1123) then 'motorway_link'
(1200, 1300, 5301) then 'primary'
(1221, 1222, 1223, 1321) then 'primary_link'
(1400, 5401, 5451) then 'secondary'
(1421, 1471) then 'secondary_link'
(1450, 5402, 5500, 5501) then 'tertiary'
(1521) then 'tertiary_link'
(1500, 1550, 1700, 1740, 2000, 8224)
(1500, 1550, 1560, 1600, 1700, 1740, 1750, 1760, 1800, 1850, 2000, 8224) then 'service'
(9000) then 'track'
(1600) then 'alley'
(1750, 1850) then 'driveway'
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
    regexp_replace(st_name, '(\s)Av[e]?(-|\s|$)', '\1Avenue\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Blvd(-|\s|$)', '\1Boulevard\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Br[g]?(-|\s|$)', '\1Bridge\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Ct(-|\s|$)', '\1Court\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Dr(-|\s|$)', '\1Drive\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Fwy(-|\s|$)', '\1Freeway\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Hwy(-|\s|$)', '\1Highway\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Pkwy(-|\s|$)', '\1Parkway\2 ', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Pl(-|\s|$)', '\1Place\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Rd(-|\s|$)', '\1Road\2 ', 'gi');
--St--> Street (will not occur at beginning of a st_name)
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)St(-|\s|$)', '\1Street\2 ', 'gi');

--Expand other abbreviated parts of street basename
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Cc(-|\s|$)', '\1Community College\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Co(-|\s|$)', '\1County\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Jr(-|\s|$)', '\1Junior\2', 'gi');
--Mt at beginning of name is 'Mount' later in name is 'Mountain'
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|-|-\s)Mt(\s)', '\1Mount\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Mt(-|\s|$)', '\1Mountain\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Nfd(-|\s|$)', '\1National Forest Development Road\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Tc(-|\s|$)', '\1Transit Center\2', 'gi');
--St--> Saint (will only occur at the beginning of a street name)
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|-|-\s)(Mt\s|Mount\s|Old\s)?St[\.]?(\s)', '\1\2Saint\3', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Us(-|\s|$)', '\1United States\2', 'gi');

--special case grammar fixes and name expansions
update osm_sts_staging set st_name =
    --the '~' operator does a posix regular expression comparison between strings
    case when st_name ~ '.*(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$).*'
    then format_titlecase(regexp_replace(st_name,
        '(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3', 'gi'))
    else st_name end;

update osm_sts_staging set st_name =
    case when st_name ~ '.*(^|\s|-)Ft\sOf\s.*' then
        case when st_name ~ '.*(^|\s|-)Holladay(-|\s|$).*'
            then regexp_replace(st_name, 'Ft\sOf\sN', 'Foot of North', 'gi')
        when st_name ~ '.*(^|\s|-)(Madison|Marion)(-|\s|$).*'
            then regexp_replace(st_name, 'Ft\sOf\sSe', 'Foot of Southeast', 'gi')
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
update osm_sts_staging set st_name = 'John Quincy Adams'
    where st_name = 'Jq Adams';
update osm_sts_staging set st_name = 'Sunnyside Hospital-Mount Scott Medical Transit Center'
    where st_name = 'Sunnyside Hosp-Mount Scott Med Transit Center';


--4) Now that abbreviations in street names have been expanded concatenate their parts
--concat strategy via http://www.laudatio.com/wordpress/2009/04/01/a-better-concat-for-postgresql/
update osm_sts_staging set
    name = array_to_string(array[st_prefix, st_name, st_type, st_direction], ' ')
    where highway != 'motorway_link'
        or highway is null;

--motorway_link's will have descriptions rather than names via osm convention
--source: http://wiki.openstreetmap.org/wiki/Link_%28highway%29
update osm_sts_staging set
    descriptn = array_to_string(array[st_prefix, st_name, st_type, st_direction], ' ')
    where highway = 'motorway_link';


# this may help in determining how to merge connected segments with
# common attribute with python, replicating what is done with postgis
# below: http://gis.stackexchange.com/questions/61474/

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