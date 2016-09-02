--get all word in rlis trail's trailname field that are four characters or less
with trailname_parsed(word) as (
    select regexp_split_to_table(trailname, E'\\s+') as word
    from trails)
select distinct word
from trailname_parsed
where char_length(word) < 5
order by word;

--get all word in rlis street's streetname field that are four characters or less
with streetname_parsed(word) as (
    select regexp_split_to_table(streetname, E'\\s+')
    from streets)
select distinct word
from streetname_parsed
where char_length(word) < 5
order by word;

--check individual values with a queries similar to these
select distinct trailname
from trails
where trailname ~* '(^|\s|-)terr[\.]?(-|\s|$)'

select distinct prefix, streetname, ftype, direction
from streets
where streetname ~* '(^|\s|-)terr[\.]?(-|\s|$)'