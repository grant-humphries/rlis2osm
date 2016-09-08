import re

from titlecase import set_small_word_list, titlecase, SMALL


SPECIAL_CASE = [
    # names
    ('AM', 'Archibald M', 'fm'),  # 'AM Kennedy Park Trails'
    ('HM', 'Howard M', 'fm'),  # 'HM Terpenning Recreation Complex Trails - Connector'
    ('JQ', 'John Quincy', 'fm'),  # Adams
    ('UJ', 'Ulin J', 'fm'),  # 'UJ Hamby Park Trails'

    # regional
    ('BES', 'Bureau of Environmental Services', 'a'),  # 'Bes Water Quality Control Lab Trail'
    ('BPA', 'Bonneville Power Administration', 'a'),
    ('MAX', 'Metropolitan Area Express', 'a'),
    ('PCC', 'Portland Community College', 'a'),
    ('PKW', 'Peterkort Woods', 'fm'),  # 'Renaissance at Pkw Homeowners Trails'
    ('PSU', 'Portland State University', 'a'),
    ('SWC', 'Southwest Corridor', 'a'),  # 'Proposed Regional Swc Connector'
    ('THPRD', 'Tualatin Hills Park & Recreation District', 'a'),
    ('TVWD', 'Tualatin Valley Water District', 'a'),  # 'Tvwd Water Treatment Plant Trails'
    ('WES', 'Westside Express Service', 'a'),
    ('WSU', 'Washington State University' 'a')  # 'Wsu Campus Trails'
]


class StreetNameExpander(object):
    DIRECTION = {
        'N': 'North',
        'NE': 'Northeast',
        'E': 'East',
        'SE': 'Southeast',
        'S': 'South',
        'SW': 'Southwest',
        'W': 'West',
        'NW': 'Northwest',

        'NB': 'Northbound',
        'EB': 'Eastbound',
        'SB': 'Southbound',
        'WB': 'Westbound'
    }

    # these will appear as the end of the street name only
    TYPE = {
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
        'TERR': 'Terrace',
        'TRL': 'Trail',
        'VIA': 'Viaduct',
        'VW': 'View',
        'WY': 'Way'
    }

    # general for United States
    # columns are abbreviation, expansion, allows positions
    BASENAME = [
        ('ASSN', 'Association', 'a'),
        ('CC', 'Community College', ),
        ('CO', 'County', ),
        ('ES', 'Elementary School', 'ml'),
        ('ESL', 'Elementary School', 'ml'),
        ('FT', 'Foot', ),
        ('HOA', 'Homeowners Association', 'a'),
        ('HOSP', 'Hospital', ),
        ('HMWRS', 'Homeowners', 'a'),
        ('INC', 'Incorporated', ),
        ('JR', 'Junior', ),
        ('LDS', 'Latter Day Saints', ),  # 'Lds Trails'
        ('LLC', 'Limited Liability Company', ),  # 'Orenco Gardens Llc Park Trails'
        ('MED', 'Medical', ),
        ('MLK', 'Martin Luther King', ),
        ('MS', 'Middle School', 'ml'),
        ('MT', 'Mount', 'fm'),
        ('MT', 'Mountain', 'l'),
        ('MTN', 'Mountain', ),
        ('NFD', 'Nation Forest Development Road', ),
        ('NO', 'Number', ),  # 'Pacific Grove No 4 Homeowners Association Trails'
        ('PED', 'Pedestrian', 'a'),
        ('ROW', 'Right of Way', ),  # 'Fanno Creek Trail at Oregon Electric ROW', issue with type: Row?
        ('RR', 'Railroad', 'ml'),  # not at start
        ('ST', 'Saint', 'fm'),
        ('TC', 'Transit Center', 'a'),
        ('US', 'United States', ),
        ('VA', 'Veteran Affairs')
    ]

    def __init__(self, delimiter='-', separators=(' ', '/'), special_cases=None):
        """In this context a delimiter is a character that divides what
        could be two distinct names that have been combined into one,
        separators are characters between words that together form a
        single name
        """

        self.delimiter = delimiter
        self.separators = separators
        self.special_cases = special_cases

        self.expander = self._prep_expander()

        # TODO consider handling case changes outside of this class
        self.tcase_callback = customize_titlecase()

    def _prep_expander(self):
        combo_dir = {a: x for a, x in self.DIRECTION.items() if len(a) > 1}
        
        if self.special_cases:
            self.BASENAME += self.special_cases

        # first, middle and last refer to the position of the word in
        # name that is being expanded
        f_dict, m_dict, l_dict = {}, {}, {}
        for k, v, placement in self.BASENAME:
            # a = any, f = first, m = middle, l = last
            for p in placement:
                if p == 'a':
                    f_dict[k] = v
                    m_dict[k] = v
                    l_dict[k] = v
                elif p == 'f':
                    f_dict[k] = v
                elif p == 'm':
                    m_dict[k] = v
                elif p == 'l':
                    l_dict[k] = v

        # order matters here, some entries in 'type' are being overwritten
        # by items originally from 'basename'
        f_list = [self.DIRECTION, self.TYPE, f_dict]
        m_list = [combo_dir, self.TYPE, m_dict]
        l_list = [self.DIRECTION, self.TYPE, l_dict]

        return {
            'first': self._merge_dicts(*f_list),
            'middle': self._merge_dicts(*m_list),
            'last': self._merge_dicts(*l_list)
        }

    def _merge_dicts(*dict_args):
        master_dict = dict()

        for dict_ in dict_args:
            master_dict.update(dict_)

        return master_dict

    def basename(self, name):
        # remove any periods and split at delimiter
        parts = name.replace('.', '').split(self.delimiter)
        part_list = list()

        for p in parts:
            word_list = list()
            split_regex = '([{}]+)'.format(''.join(self.separators))
            words = re.split(split_regex, p.strip())  # remove edge whitespace
            num_words = len([w for w in words if w and w not in self.separators])
            word_pos = 1

            # if name is two word or less abbreviation positional trends
            # are different
            for w in words:
                if w and w not in self.separators:
                    # mappings assume abbreviated words are all caps
                    uw = w.upper()

                    # first word
                    if word_pos == 1 and num_words > 2:
                        w = self.expander['first'].get(uw, w)
                    # last word
                    elif word_pos == num_words and num_words > 2:
                        w = self.expander['last'].get(uw, w)
                    # middle word(s)
                    else:
                        w = self.expander['middle'].get(uw, w)

                    word_pos += 1
                word_list.append(w)
            part_list.append(word_list)

        return self.delimiter.join([''.join(wl) for wl in part_list])

    def type(self, street_type):
        return self.TYPE.get(street_type.upper(), street_type)

    def direction(self, direct):
        return self.DIRECTION.get(direct.upper(), direct)


def customize_titlecase():

    # don't lowercase 'v', do lowercase 'with'
    small = SMALL.replace('|v\.?|', '|')
    small = '{}|with'.format(small)
    set_small_word_list(small)

    def number_after_letter(word, **kwargs):
        # even though the kwargs aren't used here they are a requirement of
        # any function supplied to titlecase as a callback

        if word[0].isdigit() and word[-1].isalpha():
            # cases like '45th'
            if word[-2].isalpha():
                word.lower()
            # cases like '99W'
            else:
                word.upper()

        return word

    return number_after_letter


# trail fields that need expansion, titlecasing
# trailname
# sharedname
# systemname
# agencyname

# Unknown Abbreviation, switch back to caps
# SYSTEMNAME
# 'Pbh Inc Trails', 'PBH Incorporated Trails'
# TRAILNAME
# 'Faof Canberra Trail', 'FAOF Canberra Trail'
# 'Tbbv Path', 'TBBV Path'

# Grammar Fixes, this might able to be handled by the titlecase module
# AGENCYNAME
# '(^|\s|-)Trimet(-|\s|$)', '\1TriMet\2'

# Typo Fixes - these should be reported to Metro
# SYSTEMNAME
# 'Chiefain Dakota Greenway Trails', 'Chieftain'
# 'Tanasbource Villas Trail', 'Tanasbourne'
# 'Southwest Portland Wilamette Greenway Trail', 'Willamette'
# TRAILNAME
# 'Andrea Street - Mo Ccasin Connector', 'Moccasin'
# 'West Unioin Road - 151st Place Connector', 'Union'
# '106th - Mll Ct Connector', 'Mll' should be Mill

# Special Case Incorrect Expansions
# STREETS
# 'FT OF N HOLLADAY': 'N' won't be expanded to North
# 'US GRANT': should be Ulysses S; will be United States
# TRAILS
# 'Gardenia St - E St Connector': E will be expanded to East
# 'Fulton CC Driveway': CC is normally community college, but here it's community center
