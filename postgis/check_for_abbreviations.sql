--get all words in rlis trail's trailname field that are four characters or less
select distinct tn_words
from (select regexp_split_to_table(trailname, E'\\s+') as tn_words
		from rlis_trails) trailname_parsed
where char_length(tn_words) < 5
order by tn_words;

--get all words in rlis street's streetname field that are four characters or less
select distinct sn_words
from (select regexp_split_to_table(streetname, E'\\s+') as sn_words
		from rlis_streets) streetname_parsed
where char_length(sn_words) < 5
order by sn_words;

--check individual values with a query similar to this
select distinct trailname
from rlis_trails
where trailname ~* '(^|\s|-)terr[\.]?(-|\s|$)'