--put all words that are a part of street and trail names as individual
--entries in a table
drop table if exists words cascade;
create table words as
    --split names at dashes and combine them into a single table, with
    --record of position in the original string
    with dash_split as (
        select distinct
            phrase, streetname as full_name, phrase_pos,
            'streetname'::text as field
        from streets, regexp_split_to_table(streetname, '\s*-+\s*')
            with ordinality x(phrase, phrase_pos)
                union all
        select distinct
            phrase, trailname, phrase_pos, 'trailname'
        from trails, regexp_split_to_table(trailname, '\s*-+\s*')
            with ordinality x(phrase, phrase_pos)
                union all
        select distinct
            phrase, sharedname, phrase_pos, 'sharedname'
        from trails, regexp_split_to_table(sharedname, '\s*-+\s*')
            with ordinality x(phrase, phrase_pos)
                union all
        select distinct
            phrase, systemname, phrase_pos, 'systemname'
        from trails, regexp_split_to_table(systemname, '\s*-+\s*')
            with ordinality x(phrase, phrase_pos)
                union all
        select distinct
            phrase, agencyname , phrase_pos, 'agencyname'
        from trails, regexp_split_to_table(agencyname, '\s*-+\s*')
            with ordinality x(phrase, phrase_pos)
    )

    --split phrases at spaces and forward slash with record of each
    --word position in the phrase
    select
        word, full_name, word_pos, phrase_pos, char_length(word) as word_len,
        array_length(regexp_split_to_array(phrase, '[\s/]+'), 1) as phrase_len,
        field
    from dash_split, regexp_split_to_table(phrase, '[\s/]+')
        with ordinality x(word, word_pos);

alter table words add column id serial primary key;

create index word_ix on words using btree (word);
create index field_ix on words using btree (field);
create index word_len_ix on words using btree (word_len);
