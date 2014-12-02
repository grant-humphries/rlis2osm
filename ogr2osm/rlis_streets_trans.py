def filterTags(tags):
	if tags is None:
		return
	newtags = {}
	for (key, value) in tags.items():
		if value != '':
			# id is included here, but nor handled later because I want to get rid of it
			if key not in ('localid', 'pc_left', 'pc_right', 'id'):
				newtags[key] = value
			else:
				if key == 'localid':
					newtags['RLIS:localid'] = value
				elif key == 'pc_left':
					newtags['addr:postcode:left'] = value
				elif key == 'pc_right':
					newtags['addr:postcode:right'] = value
	return newtags