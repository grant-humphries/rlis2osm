# Python Version: 2.7.5
#--------------------------------

# In this case the translation file is being used to expand fields (keys) that
# had to be truncated due to the .dbf spec associated with shapefiles
def filterTags(tags):
	if tags is None:
		return
	newtags = {}
	for (key, value) in tags.items():
		if value != '':
			if key == 'abndnd_hwy':
				newtags['abandoned:highway'] = value
			elif key == 'cnstrctn':
				newtags['construction'] = value
			elif key == 'r_sysname':
				newtags['RLIS:systemname'] = value
			else:
				newtags[key] = value
	
	return newtags