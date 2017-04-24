import re


class StreetNameExpander(object):
    """Expand abbreviations in a supplied street names string

    Provides methods to expand both parsed and unparsed street names.

    Attributes:
        delimiter (str): Character that divides what two distinct
            street names that have been combined in a single descriptor
        separators (tup): Characters between words that are a part of a
            single street name
        custom_abbrevs (list): A list of tuples that contain custom
            abbreviations and their corresponding full names that will
            be added to the default expansions used by the `basename`
            method . The tuples should have three elements in this
            order: the abbreviation, the full name and the positions
            within a name that the abbreviated words should be
            expanded. Those positions are represented by the following
            strings:
                'a' = any
                'f' = first
                'm' = middle
                'l' = last
            These characters can also be combined to indicate multiple
            positions, such as 'fm' for first and middle, order does
            not matter when multiple characters are used
        overrides (dict):
            Expansions are performed based on the characters that
            comprise the abbreviation and the position of the
            abbreviation in the street name that it belongs to. Because
            this logic is simple it will occasionally fail to do what
            the user intends.  The `overrides` parameter allows the user
            to supply a full, raw street name and it expanded
            counterpart as key value pairs and if the value supplied to
            the `basename` method matches an override key it will be
            expanded to its value and bypass the default expansion logic
    """

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

    # abbreviations here are common to the United States, see the
    # descriptions of the 'custom_abbrevs' attribute in the class
    # docstring for an explanation of this object
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

    def __init__(self, delimiter='-', separators=(' ', '/'),
                 custom_abbrevs=None, overrides=None):
        self.delimiter = delimiter
        self.separators = separators
        self.custom_abbrevs = custom_abbrevs
        self.overrides = overrides
        self.expander = self._prep_expander()

    def _prep_expander(self):
        combo_dir = {a: x for a, x in self.DIRECTION.iteritems() if len(a) > 1}
        
        if self.custom_abbrevs:
            self.BASENAME += self.custom_abbrevs

        # first, middle and last refer to the position of the word in
        # name that is being expanded
        f_dict, m_dict, l_dict = dict(), dict(), dict()

        # a = any, f = first, m = middle, l = last
        for k, v, placement in self.BASENAME:
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

        if self.overrides:
            overridden = self.overrides.get(name)

            if overridden:
                return overridden

        # remove any periods and split at delimiter
        parts = name.replace('.', '').split(self.delimiter)
        part_list = list()

        for p in parts:
            word_list = list()
            split_regex = '([{}]+)'.format(''.join(self.separators))
            words = re.split(split_regex, p.strip())  # strip whitespace
            num_words = len([w for w in words if w and w not in self.separators])
            word_pos = 1

            # if name is two word or less abbreviation positional trends
            # are different
            for w in words:
                if w and w not in self.separators:
                    # mappings assume abbreviated words are all caps
                    uw = w.upper()

                    # first word
                    if word_pos == 1 and num_words > 1:
                        w = self.expander['first'].get(uw, w)
                    # last word
                    elif word_pos == num_words and num_words > 1:
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
