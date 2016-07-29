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