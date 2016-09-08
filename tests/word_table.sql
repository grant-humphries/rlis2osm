--put all words that are a part of street and trail names as individual
--entries in a table
drop table if exists words cascade;
create table words as
    select distinct
        regexp_split_to_table(streetname, E'\\s+')::text as word,
        'streetname'::text as field, streetname as fullname
    from streets
        union all
    select distinct
        regexp_split_to_table(trailname, E'\\s+'), 'trailname',
        trailname
    from trails
        union all
    select distinct
        regexp_split_to_table(sharedname, E'\\s+'), 'sharedname',
        sharedname
    from trails
        union all
    select distinct
        regexp_split_to_table(systemname, E'\\s+') , 'systemname',
        systemname
    from trails
        union all
    select distinct
        regexp_split_to_table(agencyname, E'\\s+'), 'agencyname',
        agencyname
    from trails;

alter table words add len int;
update words set len = char_length(word);

create index word_ix on words using BTREE (word);
create index field_ix on words using BTREE (field);
create index len_ix on words using BTREE (len);
