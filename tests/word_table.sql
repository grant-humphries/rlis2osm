--put all words that are a part of street and trail names as individual
--entries in a table
drop table if exists words cascade;
create table words as
    --split names at dashes and combine them into a single table, with
    --record of position in the original string
    with dash_split as (
        select distinct
            phrase, streetname as fullname, delimiter_pos,
            'streetname'::text as field
        from streets, regexp_split_to_table(streetname, '\s*-+\s*')
            with ordinality x(phrase, delimiter_pos)
                union all
        select distinct
            phrase, trailname, delimiter_pos, 'trailname'
        from trails, regexp_split_to_table(trailname, '\s*-+\s*')
            with ordinality x(phrase, delimiter_pos)
                union all
        select distinct
            phrase, sharedname, delimiter_pos, 'sharedname'
        from trails, regexp_split_to_table(sharedname, '\s*-+\s*')
            with ordinality x(phrase, delimiter_pos)
                union all
        select distinct
            phrase, systemname, delimiter_pos, 'systemname'
        from trails, regexp_split_to_table(systemname, '\s*-+\s*')
            with ordinality x(phrase, delimiter_pos)
                union all
        select distinct
            phrase, agencyname , delimiter_pos, 'agencyname'
        from trails, regexp_split_to_table(agencyname, '\s*-+\s*')
            with ordinality x(phrase, delimiter_pos))

    --split phrases at spaces and forward slash with record of each
    --word position in the phrase
    select
        word, fullname, separator_pos, delimiter_pos,
        char_length(word) as word_length, field
    from dash_split, regexp_split_to_table(phrase, '[\s/]+')
        with ordinality x(word, separator_pos);

create index word_ix on words using BTREE (word);
create index field_ix on words using BTREE (field);
create index len_ix on words using BTREE (word_length);
