
def filterTags(tags):
    """expand tag-key names that were that could not be in there full
    due to the .dbf spec field name limitations, this function must
    have the exact name 'filterTags' to work with ogr2osm
    """

    if not tags:
        return

    key_repair_dict = dict(
        abandoned_='abandoned:highway',
        constructi='construction',
        descriptio='description',
        RLIS_bicyc='RLIS:bicycle'
    )

    repaired_tags = dict()
    for k, v in tags.iteritems():
        if v != '' and v is not None:
            k = key_repair_dict.get(k, k)
            repaired_tags[k] = v

    return repaired_tags
