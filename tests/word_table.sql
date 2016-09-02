--put all words that are a part of street and trail names as individual
--entries in a table
drop table if exists short_words cascade;
create table short_words as
    select
        regexp_split_to_table(streetname, E'\\s+')::text as word,
        'streetname'::text as field, char_length(streetname)::int as len
    from streets
        union all
    select
        regexp_split_to_table(trailname, E'\\s+'), 'trailname',
        char_length(trailname)
    from trails;
    select
        regexp_split_to_table(sharedname, E'\\s+'), 'sharedname',
        char_length(sharedname)
    from trails
        union all
    select
        regexp_split_to_table(systemname, E'\\s+') , 'systemname',
        char_length(systemname)
    from trails
        union all
    select
        regexp_split_to_table(agencyname, E'\\s+'), 'agencyname',
        char_length(agencyname)
    from trails;

create index word_ix on short_words using BTREE (word);
create index field_ix on short_words using BTREE (field);
create index len_ix on short_words using BTREE (len);
