from os.path import basename, join

import fiona
from titlecase import set_small_word_list, titlecase, SMALL

from rlis2osm.data import RlisPaths
from rlis2osm.utils import zip_path


class StreetNameExpander(object):
    SINGLE_DIR_MAP = {
        'E': 'East',
        'N': 'North',
        'S': 'South',
        'W': 'West'
    }

    COMBO_DIR_MAP = {
        'EB': 'Eastbound',
        'NB': 'Northbound',
        'NE': 'Northeast',
        'NW': 'Northwest',
        'SB': 'Southbound',
        'SE': 'Southeast',
        'SW': 'Southwest',
        'WB': 'Westbound'
    }

    BASENAME_MAP = {
        'BPA': 'Bonneville Power Administration',
        'CC': 'Community College',
        'CO': 'County',
        'FT': 'Foot',
        'HOSP': 'Hospital',
        'MED': 'Medical',
        'JQ': 'John Quincy',  # Adams
        'JR': 'Junior',
        'MTN': 'Mountain',
        'NFD': 'Nation Forest Development Road',
        'PCC': 'Portland Community College',
        'TC': 'Transit Center',
        'US': 'United States'  # there is a US Grant which is Ulysses S
    }

    # these will appear as the end of the street name only
    SUFFIX_MAP = {
        'ALY': 'Alley',
        'AV': 'Avenue',
        'AVE': 'Avenue',
        'BLVD': 'Boulevard',
        'BR': 'Bridge',
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
        'VW': 'View',
        'WY': 'Way'
    }

    NOT_END = {
        'MT': 'Mount',  # maps to 'Mountain' at end
        'ST': 'Saint',  # this should override ST --> Street in some cases
    }

    END_ONLY = {
        'MT': 'Mountain'
    }

    def __init__(self, src_path, dst_dir, parsed=False, name_parts=None):
        """name_parts is dictionary specifying the parse fields that comprise
        street name and should have the following keys: prefix, base_name,
        type, suffix
        """
        self.src_path = src_path
        self.dst_path = join(dst_dir, 'expanded_{}'.format(basename(src_path)))
        self.parsed = parsed
        self.name_parts = name_parts

        # TODO consider handling case changes outside of this class
        self.tcase_callback = customize_titlecase()

    def expand_parsed(self):
        streets = fiona.open(**zip_path(self.src_path))
        metadata = streets.meta.copy()

        direction_map = merge_dicts(self.SINGLE_DIR_MAP, self.COMBO_DIR_MAP)
        front_map = merge_dicts(
            direction_map, self.BASENAME_MAP, self.SUFFIX_MAP, self.NOT_END)
        middle_map = merge_dicts(
            self.COMBO_DIR_MAP, self.BASENAME_MAP, self.SUFFIX_MAP, self.NOT_END)
        back_map = merge_dicts(
            direction_map, self.BASENAME_MAP, self.SUFFIX_MAP, self.END_ONLY)

        with fiona.open(self.dst_path, 'w', **metadata) as expanded_streets:
            for feat in streets:
                tags = feat['properties']
                prefix = tags['PREFIX']
                street_name = tags['STREETNAME'] or ''
                f_type = tags['FTYPE'] or ''
                direction = tags['DIRECTION']

                tags['PREFIX'] = direction_map.get(prefix, prefix)
                tags['STREETNAME'] = self._expand_basename(
                    street_name, front_map, middle_map, back_map)
                tags['FTYPE'] = self.SUFFIX_MAP.get(f_type, f_type).title()
                tags['DIRECTION'] = direction_map.get(direction, direction)

                expanded_streets.write(feat)

        streets.close()

    def expand_unparsed(self):
        pass

    def _expand_basename(self, street_name, front, middle, back):
        # some street names are composed like this:
        # 'SW 5TH AVE-SW MORRISON ST', so first break them into parts
        part_list = list()
        parts = street_name.split('-')
        for p in parts:
            word_list = list()
            words = p.split()
            num_words = len(words)
            for i, w in enumerate(words, 1):
                # first word
                if i == 1 and num_words > 1:
                    w = front.get(w, w)
                # last word
                elif i == num_words and num_words > 1:
                    w = back.get(w, w)
                # middle word(s)
                else:
                    w = middle.get(w, w)
                word_list.append(w)
            part_list.append(word_list)

        # the title case module seems to only work when starting from
        # lowercase
        expanded_name = '-'.join([' '.join(p) for p in part_list])
        return titlecase(expanded_name.lower(), callback=self.tcase_callback)

    def _get_fix_mapping(self):
        pass

    def _get_type_mapping(self):
        pass


def merge_dicts(*dict_args):
    master_dict = dict()

    for dict_ in dict_args:
        master_dict.update(dict_)

    return master_dict


def customize_titlecase():

    # don't lowercase 'v', do lowercase 'with'
    small = SMALL.replace('|v\.?|', '|')
    small = '{}|with'.format(small)
    set_small_word_list(small)

    def number_after_letter(word, **kwargs):
        # even though the kwargs aren't used here they are a requirement of
        # any function supplied to titlecase as a callback

        if word[0].isdigit() and word[-1].isalpha():
            # cases like 45th
            if word[-2].isalpha():
                word.lower()
            # cases like 99W
            else:
                word.upper()

        return word

    return number_after_letter


# TODO: handle streets with STREETNAME 'UNNAMED'


# # STREETS SPECIAL CASE EXPANSIONS
# 'FT OF N HOLLADAY'
# 'US GRANT'
# 'A v DAVIS'
# 99w

# # special case grammar fixes and name expansions
# if '.*(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$).*':
#     '(^|\s|-)O(brien|day|neal|neil[l]?)(-|\s|$)', '\1O''\2\3'


def main():
    paths = RlisPaths()
    street_expander = StreetNameExpander(paths.streets, paths.prj_dir)
    street_expander.expand_abbreviations()


if __name__ == '__main__':
    main()

trails_special_cases = {

}

# # TRAILS SPECIAL CASE EXPANSIONS
#
# # trail fields that need expansion, titlecasing
# # trailname
# # sharedname
# # systemname
# # agencyname
#
# # a) 'name' (aka trailname)
# # remove any periods (.) in trailname (do this for all name fields in trails)
# name.replace('.', '')

# # expand street types in trailname (the ones left are special cases)
# '(\s|/)Ct(-|\s|$)', '\1Court\2'
# '(\s)Dr(-|\s|$|/)', '\1Drive\2'
# '(\s)Ter[r]?(-|\s|$)', '\1Terrace\2'

# # expand other abbreviations in trailname
# '(\s)Assn(-|\s|$)', '\1Association\2'
'BPA', 'Bonneville Power Administration'
# '(\s)Jr(-|\s|$)', '\1Junior\2'
'PED': 'Pedestrian'
# '(^|\s|-)Us(\s)', '\1United States\2'
'VA': 'Veteran Affairs'

# # special cases, since these are not common an index is being added to 'name' field
# # and matches are being made on the full value to increase speed
'BES': 'Bureau of Environmental Services'  # 'Bes Water Quality Control Lab Trail'
'ROW': 'Right of Way'  # 'Fanno Creek Trail at Oregon Electric ROW', issue with row type?
'CC': 'Community Center'  # 'Fulton Cc Driveway', issue with community college?
'CC': 'Community College'  # 'Mount Hood Cc Driveway - Kane Drive Connector'

# # unknown abbreviation, switch back to caps
# 'Cat Road (Retired)', 'CAT Road (Retired)'
# 'Faof Canberra Trail', 'FAOF Canberra Trail'
# 'Tbbv Path', 'TBBV Path'
#
# # b) 'alt_name' (aka sharedname)
#
# # expand abbreviations
'WES': 'Westside Express Service'
#
# # c) 'r_sysname' (aka systemname)

# # expand other abbreviations
'ASSN': 'Association'
'ES': 'Elementary School'  # not at start
'ESL': 'Elementary School'  # not at start
'HOA': 'Homeowners Association'
'HMWRS': 'Homeowners'
'MS': 'Middle School'  # not at start
'RR': 'Railroad'  # not at start

'MAX': 'Metropolitan Area Express'

# # special case expansions
'AM': 'Archibald M' # 'AM Kennedy Park Trails'
'HM': 'Howard M'  # 'HM Terpenning Recreation Complex Trails - Connector'
'UJ': 'Ulin J'  # 'Uj Hamby Park Trails'


'LDS': 'Latter Day Saints'  # 'Lds Trails'
'LLC': 'Limited Liability Company' # 'Orenco Gardens Llc Park Trails'
'NO': 'Number'  # 'Pacific Grove No 4 Homeowners Association Trails',
'PKW': 'Peterkort Woods'  # 'Renaissance at Pkw Homeowners Trails'
'SWC': 'Southwest Corridor'  # 'Proposed Regional Swc Connector'


'PCC': 'Portland Community College'
'PSU': 'Portland State University'
'THPRD': 'Tualatin Hills Park & Recreation District'
'TVWD': 'Tualatin Valley Water District'  # 'Tvwd Water Treatment Plant Trails'
'WSU': 'Washington State University'  # 'Wsu Campus Trails'

# # unknown abbreviation, switch back to caps
# 'Pbh Inc Trails', 'PBH Incorporated Trails'
#

# # d) 'operator' (aka agencyname)
#
# # grammar fixes, this might able to be handled by the titlecase module
# '(^|\s|-)Trimet(-|\s|$)', '\1TriMet\2'

# Typo Fixes - these should be reported to Metro
# SYSTEMNAME
# 'Chiefain Dakota Greenway Trails', 'Chieftain Dakota Greenway Trails'
# 'Tanasbource Villas Trail', 'Tanasbourne Villas Trail'
# 'Southwest Portland Wilamette Greenway Trail', 'Southwest Portland Willamette Greenway Trail'
# TRAILNAME
# 'Andrea Street - Mo Ccasin Connector', 'Andrea Street - Moccasin Connector'
# 'West Unioin Road - 151st Place Connector', 'West Union Road - 151st Place Connector'
#