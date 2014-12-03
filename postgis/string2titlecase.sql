--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--Convert a PostGreSQL String to Title Case 
--Function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> 
--http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php
--modified to suit this project by Grant Humphries

create or replace function "format_titlecase" ("v_inputstring" text)
returns text as
$body$

declare
	ix int;
	curChar char(1);
	outString text;
	inString text;

begin
	inString := v_InputString;
	--cures problem where string starts with blank space and removes back-to-back spaces
	inString := regexp_replace(ltrim(rtrim(inString)), '\s{2,}', ' ', 'g'); 
	outString := lower(inString);
	ix := 1;
	--replaces 1st char of Output with uppercase of 1st char from input
	outString := overlay(outString placing upper(substr(inString, 1, 1)) from 1 for 1); 
	
	while ix <= length(inString) loop
		curChar := substr(inString, ix, 1); 
		--gets loop's working character
		if ix+1 <= length(inString) then
			--if the working character is an apostrophe and there is not a dash, 
			--space or end of line two characters later
			if curChar = '''' and substr(inString, ix+2, 1) !~ '(-|\s)' 
				and ix+2 != length(inString) then
					outString := overlay(outString placing 
					upper(substr(inString, ix+1, 1)) from ix+1 for 1);
			--if the working char is an &
			elsif curChar = '&' then
				if(substr(inString, ix+1, 1)) = ' ' then
					outString := overlay(outString placing 
					upper(substr(inString, ix+2, 1)) from ix+2 for 1);
				else
					outString := overlay(outString placing 
					upper(substr(inString, ix+1, 1)) from ix+1 for 1);
				end if;
			--special case for handling 'Mc' as in McDonald
			elsif lower(curChar) = 'm' and lower(substr(inString, ix+1, 1)) = 'c' 
				and (substring(inString, ix-1, 1) ~ '(-|\s)' or ix=1) then
					outString := overlay(outString placing 
					upper(substr(inString, ix, 1)) from ix for 1);
					--makes the 'C' lower case.
					outString := overlay(outString 
					placing lower(substr(inString, ix+1, 1)) from ix+1 for 1);
					--makes the letter after the 'c' upper case
					outString := overlay(outString placing 
					upper(substr(inString, ix+2, 1)) from ix+2 for 1);
					--we took care of the char acfter 'c' (we handled 2 letters instead 
					--of only 1 as usual), so we need to advance.
					ix := ix+1;
			--capitalize letters that follow all of these characters, barring special cases 
			--identified below
			elsif (curChar in (' ',';',':','!','?',',','.','_','-','/','(',chr(9)) 
				and substr(inString, ix+1, 1) !~ '(-|\s)') or (curChar ~ '[0-9]' 
				and lower(substring(inString, ix+1, 2)) !~ '(st|nd|rd|th)') then
					outString := overlay(outString placing 
					upper(substr(inString, ix+1, 1)) from ix+1 for 1);
			end if;
		end if;

		ix := ix+1;
	end loop; 

	return coalesce(outString,'');
end;
$body$
language 'plpgsql'
volatile
called on null input
security invoker
cost 100;

/* Examples of functionality
select * from Format_TitleCase('MR DOG BREATH');
select * from Format_TitleCase('each word, mcclure of this string:shall be transformed');
select * from Format_TitleCase(' EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
select * from Format_TitleCase('mcclure and others');
select * from Format_TitleCase('J & B ART');
select * from Format_TitleCase('J&B ART');
select * from Format_TitleCase('J&B ART J & B ART this''s art''s house''s problem''s 0''shay o''should work''s EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
*/