# Python Version: 2.7.5
#--------------------------------
# In this case the translation file is being used to expand fields (keys) that
# had to be truncated due to the .dbf spec associated with shapefiles

def filterTags(tags):
	"""This function reads and potentially modifies key-value pairs, if a key has no value,
	which is common in may geoformats, it will be dropped"""
	if tags is None:
		return
	newtags = {}
	for (key, value) in tags.items():
		if value != '':
			if key == 'descriptn':
				newtags['description'] = value
			else:
				newtags[key] = value
				
	return newtags