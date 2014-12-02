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
			if key == 'trailid':
				newtags['RLIS:trailid'] = value
			elif key == 'systemname':
				newtags['RLIS:systemname'] = value
			elif key == 'mtr_vhcle':
				newtags['motor_vehicle'] = value
			elif key == 'cnstrctn':
				newtags['construction'] = value
			elif key == 'hwy_abndnd':
				newtags['highway:abandoned'] = value
			else:
				newtags[key] = value
	
	return newtags