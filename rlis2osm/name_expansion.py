import titlecase


class StreetNameExpander(object):
    def __init__(self, parsed=False):
        pass

    def _get_fix_mapping(self):
        pass

    def _get_type_mapping(self):
        pass

    prefix_suffix_map = {
        'E': 'East',
        'EB': 'Eastbound',
        'N': 'North',
        'NB': 'Northbound',
        'NE': 'Northeast',
        'NW': 'Northwest',
        'S': 'South',
        'SB': 'Southbound',
        'SE': 'Southeast',
        'SW': 'Southwest',
        'W': 'West',
        'WB': 'Westbound'
    }
    type_map = {
        'ALY': 'Alley',
        'AVE': 'Avenue',
        'BLVD': 'Boulevard',
        'BRG': 'Bridge',
        'BYP': 'Bypass',
        'CIR': 'Circle',
        'CORR': 'Corridor',
        'CRST': 'Crest',
        'CT': 'Court',
        'DR': 'Drive',
        'EXPY': 'Expressway',
        'EXT': 'Extension',
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
        'SMT': 'Summit',
        'SQ': 'Square',
        'ST': 'Street',
        'TER': 'Terrace',
        'TRL': 'Trail',
        'VIA': 'Viaduct',
        'VW': 'View'
    }


# 'alt_name' - alternate name of trail
format_titlecase(sharedname),


# STREETS SPECIAL CASE EXPANSIONS

# 3) Expand abbreviations that are within the street basename
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
# St > Street (will not occur at beginning of a st_name)
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)St(-|\s|$)', '\1Street\2 ', 'gi');

# Expand other abbreviated parts of street basename
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Cc(-|\s|$)', '\1Community College\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Co(-|\s|$)', '\1County\2', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(\s)Jr(-|\s|$)', '\1Junior\2', 'gi');
# Mt at beginning of name is 'Mount' later in name is 'Mountain'
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
# St > Saint (will only occur at the beginning of a street name)
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|-|-\s)(Mt\s|Mount\s|Old\s)?St[\.]?(\s)', '\1\2Saint\3', 'gi');
update osm_sts_staging set st_name =
    regexp_replace(st_name, '(^|\s|-)Us(-|\s|$)', '\1United States\2', 'gi');

# special case grammar fixes and name expansions
update osm_sts_staging set st_name =
    # the '~' operator does a posix regular expression comparison between strings
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

# more special case name expansions
# for these an index is created and matches are made on the full name of the
# field to decrease run time of script
update osm_sts_staging set st_name = 'Bonneville Power Administration'
    where st_name = 'Bpa';
update osm_sts_staging set st_name = 'John Quincy Adams'
    where st_name = 'Jq Adams';
update osm_sts_staging set st_name = 'Sunnyside Hospital-Mount Scott Medical Transit Center'
    where st_name = 'Sunnyside Hosp-Mount Scott Med Transit Center';





# TRAILS SPECIAL CASE EXPANSIONS

# trail fields that need expansion, titlecasing
# trailname
# sharedname
# systemname
# agencyname

# 4) Expand any abbreviations and properly format strings in the name, r_sysname,
# alt_name, and operator fields

# a) 'name' (aka trailname)
# remove any periods (.) in trailname
update osm_trls_staging set name = replace(name, '.', '');

# expand street prefixes in trailname
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

# expand street types in trailname
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

# expand other abbreviations in trailname
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

# convert transitional words in trail names to lowercase
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

# special cases, since these are not common an index is being added to 'name' field
# and matches are being made on the full value to increase speed
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

# unknown abbreviation, switch back to caps
update osm_trls_staging set name = 'CAT Road (Retired)'
    where name = 'Cat Road (Retired)';
update osm_trls_staging set name = 'FAOF Canberra Trail'
    where name = 'Faof Canberra Trail';
update osm_trls_staging set name = 'TBBV Path'
    where name = 'Tbbv Path';

# typo fixes
update osm_trls_staging set name = 'Andrea Street - Moccasin Connector'
    where name = 'Andrea Street - Mo Ccasin Connector';
update osm_trls_staging set name = 'West Union Road - 151st Place Connector'
    where name = 'West Unioin Road - 151st Place Connector';


# b) 'alt_name' (aka sharedname)

# remove periods (.)
update osm_trls_staging set alt_name = replace(alt_name, '.', '');

# expand abbreviations
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

# grammar fixes
update osm_trls_staging set alt_name =
    regexp_replace(alt_name, '(\s)And(\s)', '\1and\2', 'gi');
update osm_trls_staging set alt_name =
    regexp_replace(alt_name, '(\s)The(\s)', '\1the\2', 'gi');
update osm_trls_staging set alt_name =
    regexp_replace(alt_name, '(\s)To(\s)', '\1to\2', 'gi');

# special cases, use index and match full name
update osm_trls_staging set alt_name = 'Tualatin Valley Water District Water Treatment Plant Trails'
    where alt_name ~~* 'TVWD Water Treatment Plant Trails';


# c) 'r_sysname' (aka systemname)

# remove periods (.)
update osm_trls_staging set r_sysname = replace(r_sysname, '.', '');

# expand street prefixes
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

# expand street types
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

# expand other abbreviations
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

# special case expansions
update osm_trls_staging set r_sysname =
    regexp_replace(r_sysname, '(^|\s|-)HM(\s)', '\1Howard M\2', 'gi');

# grammar fixes
update osm_trls_staging set r_sysname =
    regexp_replace(r_sysname, '(\s)At(\s)', '\1at\2', 'gi');
update osm_trls_staging set r_sysname =
    # second 'd' is for typo fix
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

# special cases, use index and match full name
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

# unknown abbreviation, switch back to caps
update osm_trls_staging set r_sysname = 'PBH Incorporated Trails'
    where r_sysname = 'Pbh Inc Trails';

# typo fixes
update osm_trls_staging set r_sysname = 'Chieftain Dakota Greenway Trails'
    where r_sysname = 'Chiefain Dakota Greenway Trails';
update osm_trls_staging set r_sysname = 'Tanasbourne Villas Trail'
    where r_sysname = 'Tanasbource Villas Trail';
update osm_trls_staging set r_sysname = 'Southwest Portland Willamette Greenway Trail'
    where r_sysname = 'Southwest Portland Wilamette Greenway Trail';


# d) 'operator' (aka agencyname)

# expand abbreviations
update osm_trls_staging set operator =
    regexp_replace(operator, '(^|\s|-)Us(-|\s|$)', '\1Unites States\2', 'gi');

# grammar fixes
update osm_trls_staging set operator =
    regexp_replace(operator, '(\s)And(\s)', '\1and\2', 'gi');
update osm_trls_staging set operator =
    regexp_replace(operator, '(\s)Of(\s)', '\1of\2', 'gi');
update osm_trls_staging set operator =
    regexp_replace(operator, '(^|\s|-)Trimet(-|\s|$)', '\1TriMet\2', 'gi');
