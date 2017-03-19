import re


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

        # *bound
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
        ('CC', 'Community College', 'ml'),
        ('ES', 'Elementary School', 'ml'),
        ('FT', 'Foot', 'fm'),
        ('HOA', 'Homeowners Association', 'a'),
        ('HOSP', 'Hospital', 'a'),
        ('HMWRS', 'Homeowners', 'a'),
        ('INC', 'Incorporated', 'ml'),
        ('JR', 'Junior', 'a'),
        ('LDS', 'Latter Day Saints', 'a'),
        ('LLC', 'Limited Liability Company', 'a'),
        ('MED', 'Medical', 'ml'),
        ('MLK', 'Martin Luther King', 'a'),
        ('MS', 'Middle School', 'ml'),
        ('MT', 'Mount', 'fm'),
        ('MT', 'Mountain', 'l'),
        ('MTN', 'Mountain', 'a'),
        ('NFD', 'Nation Forest Development Road', 'a'),
        ('PED', 'Pedestrian', 'a'),
        ('RR', 'Railroad', 'ml'),
        ('ST', 'Saint', 'f'),
        ('TC', 'Transit Center', 'a'),
        ('US', 'United States', 'a'),
        ('VA', 'Veteran Affairs', 'f')
    ]

    def __init__(self, delimiter='-', separators=(' ', '/'), special=None):
        """In this context a delimiter is a character that divides what
        could be two distinct names that have been combined into one,
        separators are characters between words that together form a
        single name
        """

        self.delimiter = delimiter
        self.separators = separators
        self.special_cases = special
        self.expander = self._prep_expander()

    def _prep_expander(self):
        combo_dir = {a: x for a, x in self.DIRECTION.iteritems() if len(a) > 1}
        
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
                    break
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
            'first': merge_dicts(*f_list),
            'middle': merge_dicts(*m_list),
            'last': merge_dicts(*l_list)
        }

    def basename(self, name):
        if not name:
            return name

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
        return self._simple_mapping(self.TYPE, street_type)

    def direction(self, direction):
        return self._simple_mapping(self.DIRECTION, direction)

    @staticmethod
    def _simple_mapping(mapping, value):
        # input must be a string so that upper doesn't throw an error
        string = '' if value is None else str(value)
        return mapping.get(string.upper(), value)


def merge_dicts(*dict_args):
    master_dict = dict()

    for dict_ in dict_args:
        master_dict.update(dict_)

    return master_dict


# Special Case Incorrect Expansions
# STREETNAME
# 'FT OF N HOLLADAY': 'N' won't be expanded to North
# 'US GRANT': should be Ulysses S; will be United States
# 'MT ST HELENS', 'OLD ST HELENS' - 'ST' will be 'Street' not 'Saint'
# 'SW MAX CT' - will be MAX will be Metropolitan Area Express

# TRAILNAME
# 'Gardenia St - E St Connector': E will be expanded to East
# 'Fulton CC Driveway': CC is normally community college, but here it's community center
# ('ROW', 'Right of Way',),  # 'Fanno Creek Trail at Oregon Electric ROW', issue with type: Row?
# 'NW St Helens Rd', 'Proposed St Helens - Portland Regional Trail': Street/Saint problem

# Unknown Abbreviations
# SYSTEMNAME
# 'PBH Incorporated Trails'
# TRAILNAME
# 'FAOF Canberra Trail'
# 'TBBV Path'

# Typo Fixes - these should be reported to Metro
# SYSTEMNAME
# 'Chiefain Dakota Greenway Trails', 'Chieftain'
# 'Tanasbource Villas Trail', 'Tanasbourne'
# 'Southwest Portland Wilamette Greenway Trail', 'Willamette'
# TRAILNAME
# 'Andrea Street - Mo Ccasin Connector', 'Moccasin'
# 'West Unioin Road - 151st Place Connector', 'Union'
# '106th - Mll Ct Connector', 'Mll' should be Mill
