from titlecase import titlecase


class StreetNameExpander(object):
    def __init__(self, parsed=False):
        pass

    def _get_fix_mapping(self):
        pass

    def _get_type_mapping(self):
        pass

    direction_map = {
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

    misc_map = {
        'BRG': 'Bridge',
        'HOSP': 'Hospital',
        'HWY': 'Highway',  # hwy can appear at any point in basename (note that is in type dict as well
        'MT': 'Mount',  # 'saint' is usually at the beginning of a name, but not in the case of 'mount saint' and 'old saint'
        'TC': 'Transit Center',
        'ST': 'Saint',  # not be confused with street
        'US': 'United States',


    }

# TODO: handle streets with STREETNAME 'UNNAMED'

# 'alt_name' - alternate name of trail
titlecase(name)


# STREETS SPECIAL CASE EXPANSIONS

# 3) Expand abbreviations that are within the street basename
'(\s)Av[e]?(-|\s|$)', '\1Avenue\2',
'(\s)Blvd(-|\s|$)', '\1Boulevard\2 '
'(\s)Br[g]?(-|\s|$)', '\1Bridge\2 '
'(\s)Ct(-|\s|$)', '\1Court\2 '
'(\s)Dr(-|\s|$)', '\1Drive\2 '
'(^|\s|-)Fwy(-|\s|$)', '\1Freeway\2 '
'(^|\s|-)Hwy(-|\s|$)', '\1Highway\2 '
'(\s)Pkwy(-|\s|$)', '\1Parkway\2 '
'(\s)Pl(-|\s|$)', '\1Place\2'
'(\s)Rd(-|\s|$)', '\1Road\2 '
# St > Street (will not occur at beginning of a st_name)
'(\s)St(-|\s|$)', '\1Street\2 '

# Expand other abbreviated parts of street basename
'(^|\s|-)Cc(-|\s|$)', '\1Community College\2'
'(^|\s|-)Co(-|\s|$)', '\1County\2'
'(\s)Jr(-|\s|$)', '\1Junior\2'
# Mt at beginning of name is 'Mount' later in name is 'Mountain'
'(^|-|-\s)Mt(\s)', '\1Mount\2'
'(\s)Mt(-|\s|$)', '\1Mountain\2'
'(^|\s|-)Nfd(-|\s|$)', '\1National Forest Development Road\2'
'(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2'
'(\s)Tc(-|\s|$)', '\1Transit Center\2'
# St > Saint (will only occur at the beginning of a street name)
'(^|-|-\s)(Mt\s|Mount\s|Old\s)?St[\.]?(\s)', '\1\2Saint\3'
'(^|\s|-)Us(-|\s|$)', '\1United States\2'

# special case grammar fixes and name expansions
if '.*(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$).*':
    '(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3'

if '.*(^|\s|-)Ft\sOf\s.*':
    if '.*(^|\s|-)Holladay(-|\s|$).*':
        'Ft\sOf\sN', 'Foot of North'
    elif '.*(^|\s|-)(Madison|Marion)(-|\s|$).*':
        'Ft\sOf\sSe', 'Foot of Southeast'

# more special case name expansions
# for these an index is created and matches are made on the full name of the
# field to decrease run time of script
'Bpa', 'Bonneville Power Administration'
'Jq Adams', 'John Quincy Adams'
'Sunnyside Hosp-Mount Scott Med Transit Center', 'Sunnyside Hospital-Mount Scott Medical Transit Center'




# TRAILS SPECIAL CASE EXPANSIONS

# trail fields that need expansion, titlecasing
# trailname
# sharedname
# systemname
# agencyname

# 4) Expand any abbreviations and properly format strings in the name, r_sysname,
# alt_name, and operator fields

# a) 'name' (aka trailname)
# remove any periods (.) in trailname (do this for all name fields in trails)
name.replace('.', '')

# expand street prefixes in trailname
'(^|-\s|-)N(\s)', '\1North\2',
'(^|\s|-)Ne(\s)', '\1Northeast\2'
'(^|-\s|-)E(\s)', '\1East\2'
'(^|\s|-)Se(\s)', '\1Southeast\2'
'(^|-\s|-)S(\s)', '\1South\2'
'(^|\s|-)Sw(\s)', '\1Southwest\2'
'(^|-\s|-)W(\s)', '\1West\2'
'(^|\s|-)Nw(\s)', '\1Northwest\2'
'(^|\s|-)Nb(-|\s|$)', '\1Northbound\2'
'(^|\s|-)Eb(-|\s|$)', '\1Eastbound\2'
'(^|\s|-)Sb(-|\s|$)', '\1Southbound\2'
'(^|\s|-)Wb(-|\s|$)', '\1Westbound\2',

# expand street types in trailname
'(\s)Ave(-|\s|$)', '\1Avenue\2'
'(\s)Blvd(-|\s|$)', '\1Boulevard\2'
'(\s)Cir(-|\s|$)', '\1Circle\2'
'(\s|/)Ct(-|\s|$)', '\1Court\2'
'(\s)Dr(-|\s|$|/)', '\1Drive\2'
'(^|\s|-)Hwy(-|\s|$)', '\1Highway\2'
'(\s)Ln(-|\s|$)', '\1Lane\2'
'(\s)Lp(-|\s|$)', '\1Loop\2'
'(\s)Pkwy(-|\s|$)', '\1Parkway\2'
'(\s)Pl(-|\s|$)', '\1Place\2'
'(\s)Rd(-|\s|$)', '\1Road\2'
'(\s)Sq(-|\s|$)', '\1Square\2'
'(\s)St(-|\s|$)', '\1Street\2'
'(\s)Ter[r]?(-|\s|$)', '\1Terrace\2'
'(\s)Wy(-|\s|$)', '\1Way\2'

# expand other abbreviations in trailname
'(\s)Assn(-|\s|$)', '\1Association\2'
'(^|\s|-)Bpa(-|\s|$)', '\1Bonneville Power Administration\2'
'(\s)Es(-|\s|$)', '\1Elementary School\2'
'(^|\s|-)Hmwrs(-|\s|$)', '\1Homeowners\2'
'(^|\s|-)Hoa(-|\s|$)', '\1Homeowners Association\2'
'(\s)Jr(-|\s|$)', '\1Junior\2'
'(^|\s|-)Max(-|\s|$)', '\1Metropolitan Area Express\2'
'(\s)Ms(-|\s|$)', '\1Middle School\2'
'(^|\s|-)Mt(-|\s|$)', '\1Mount\2'
'(^|\s|-)Ped(-|\s|$)', '\1Pedestrian\2'
'(^|-\s|-)St(\s)', '\1Saint\2'
'(\s)Tc(-|\s|$)', '\1Transit Center\2'
'(^|\s|-)Us(\s)', '\1United States\2'
'(^|\s|-)Va(-|\s|$)', '\1Veteran Affairs\2'

# special cases, since these are not common an index is being added to 'name' field
# and matches are being made on the full value to increase speed
'Bes Water Quality Control Lab Trail', 'Bureau of Environmental Services Water Quality Control Lab Trail'

'Fanno Creek Trail at Oregon Electric ROW', 'Fanno Creek Trail at Oregon Electric Right of Way'
'Fulton Cc Driveway', 'Fulton Community Center Driveway'
'HM Terpenning Recreation Complex Trails - Connector', 'Howard M Terpenning Recreation Complex Trails - Connector'
'Shorenstein Properties Llc Connector', 'Shorenstein Properties Limited Liability Company Connector'
'Mount Hood Cc Driveway - Kane Drive Connector', 'Mt Hood Community College Driveway - Kane Dr Connector'

# unknown abbreviation, switch back to caps
'Cat Road (Retired)', 'CAT Road (Retired)'
'Faof Canberra Trail', 'FAOF Canberra Trail'
'Tbbv Path', 'TBBV Path'

# typo fixes
'Andrea Street - Mo Ccasin Connector', 'Andrea Street - Moccasin Connector'
'West Unioin Road - 151st Place Connector', 'West Union Road - 151st Place Connector'


# b) 'alt_name' (aka sharedname)

# expand abbreviations
'(\s)Ave(-|\s|$)', '\1Avenue\2'
'(\s)Ln(-|\s|$)', '\1Lane\2'
'(^|\s|-)Max(-|\s|$)', '\1Metropolitan Area Express\2'
'(^|\s|-)Mt(-|\s|$)', '\1Mount\2'
'(^|\s|-)Sw(\s)', '\1Southwest\2'
'(^|\s|-)Wes(-|\s|$)', '\1Westside Express Service\2'
'(^|\s|-)Thprd(-|\s|$)', '\1Tualatin Hills Park & Recreation District\2'

# special cases, use index and match full name
'TVWD Water Treatment Plant Trails', 'Tualatin Valley Water District Water Treatment Plant Trails'


# c) 'r_sysname' (aka systemname)

# expand street prefixes
'(^|-\s|-)N(\s)', '\1North\2'
'(^|\s|-)Ne(\s)', '\1Northeast\2'
'(^|\s|-)Nw(\s)', '\1Northwest\2'
'(^|\s|-)Se(\s)', '\1Southeast\2'
'(^|\s|-)Sw(\s)', '\1Southwest\2'

# expand street types
'(\s)Ave(-|\s|$)', '\1Avenue\2'
'(\s)Blvd(-|\s|$)', '\1Boulevard\2'
'(\s)Ct(-|\s|$)', '\1Court\2'
'(\s)Dr(-|\s|$)', '\1Drive\2'
'(^|\s|-)Hwy(-|\s|$)', '\1Highway\2'
'(\s)Ln(-|\s|$)', '\1Lane\2'
'(\s)Pl(-|\s|$)', '\1Place\2'
'(\s)Rd(-|\s|$)', '\1Road\2'
'(\s)St(-|\s|$)', '\1Street\2'

# expand other abbreviations
'(\s)Assn(-|\s|$)', '\1Association\2'
'(\s)Es[l]?(-|\s|$)', '\1Elementary School\2'
'(\s)Hoa(-|\s|$)', '\1Homeowners Association\2'
'(\s)Hmwrs(\s)', '\1Homeowners\2'
'(^|\s|-)Max(-|\s|$)', '\1Metropolitan Area Express\2'
'(\s)Ms(-|\s|$)', '\1Middle School\2'
'(^|\s|-)Mt(\s)', '\1Mount\2'
'(^|\s|-)Pcc(-|\s|$)', '\1Portland Community College\2'
'(^|\s|-)Psu(-|\s|$)', '\1Portland State University\2'
'(\s)Rr(-|\s|$)', '\1Railroad\2'
'(^|-\s|-)St(\s)', '\1Saint\2'
'(^|\s|-)Thprd(-|\s|$)', '\1Tualatin Hills Park & Recreation District\2'

# special case expansions
'(^|\s|-)HM(\s)', '\1Howard M\2'

# special cases, use index and match full name
'AM Kennedy Park Trails', 'Archibald M Kennedy Park Trails'
'Lds Trails', 'Latter Day Saints Trails'
'Orenco Gardens Llc Park Trails', 'Orenco Gardens Limited Liability Company Park Trails'
'Pacific Grove No 4 Homeowners Association Trails', 'Pacific Grove #4 Homeowners Association Trails'
'Renaissance at Pkw Homeowners Trails', 'Renaissance at Peterkort Woods Homeowners Trails'
'Proposed Regional Swc Connector', 'Proposed Regional Southwest Corridor Connector'
'Tvwd Water Treatment Plant Trails', 'Tualatin Valley Water District Water Treatment Plant Trails'
'Uj Hamby Park Trails', 'Ulin J Hamby Park Trails'
'Wsu Campus Trails', 'Washington State University Campus Trails'

# unknown abbreviation, switch back to caps
'Pbh Inc Trails', 'PBH Incorporated Trails'

# typo fixes
'Chiefain Dakota Greenway Trails', 'Chieftain Dakota Greenway Trails'
'Tanasbource Villas Trail', 'Tanasbourne Villas Trail'
'Southwest Portland Wilamette Greenway Trail', 'Southwest Portland Willamette Greenway Trail'


# d) 'operator' (aka agencyname)

# expand abbreviations
'(^|\s|-)Us(-|\s|$)', '\1Unites States\2'

# grammar fixes
'(^|\s|-)Trimet(-|\s|$)', '\1TriMet\2'
