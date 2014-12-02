def filterTags(tags):
	if tags is None:
		return
	newtags = {}
	for (key, value) in tags.items():
		if value != '':
			if key not in ('trailid', 'systemname', 'mtr_vhcle', 'cnstrctn', 'hwy_abndnd'):
				newtags[key] = value
			else:
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
	return newtags