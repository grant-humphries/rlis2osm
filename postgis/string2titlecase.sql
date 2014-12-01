--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--Convert Strings to title case 
--Function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> 
--http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php
--modified to suit this project by Grant Humphries

create or replace function "format_titlecase" ("v_inputstring" varchar)
returns varchar as
$body$

declare
	v_Index int;
	v_Char char(1);
	v_OutputString varchar(4000);
	SWV_InputString varchar(4000);

begin
	SWV_InputString := v_InputString;
	--cures problem where string starts with blank space and removes back-to-back spaces
	SWV_InputString := regexp_replace(ltrim(rtrim(SWV_InputString)), '\s+', '\s'); 
	v_OutputString := lower(SWV_InputString);
	v_Index := 1;
	--replaces 1st char of Output with uppercase of 1st char from input
	v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString, 1, 1)) from 1 for 1); 
	
	while v_Index <= length(SWV_InputString) loop
		v_Char := substr(SWV_InputString, v_Index, 1); 
		--gets loop's working character
		if v_Char in ('m','M',' ',';',':','!','?',',','.','_','-','/','&','''','(',chr(9),'0','1','2','3','4','5','6','7','8','9') then
			if v_Index+1 <= length(SWV_InputString) then
				--if the working char is an apostrophe and the letter after that is not S
				if v_Char = '''' and upper(substr(SWV_InputString,v_Index+1,1)) <> 'S' and substr(SWV_InputString,v_Index+2,1) <> repeat(' ',1) then
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
				--if the working char is an &
				elsif v_Char = '&' then
					if(substr(SWV_InputString,v_Index+1,1)) = ' ' then
						v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
					else
						v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
					end if;
				--if working character is not 'm', in this case I want single letter words to be capitalized
				--if that's not the case add the clause that the second character after the working character 
				--cannot be a space
				elsif upper(v_Char) != 'M' and (substr(SWV_InputString,v_Index+1,1) <> repeat(' ',1)) then
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
				--special case for handling 'Mc' as in McDonald
				elsif upper(v_Char) = 'M' and upper(substr(SWV_InputString,v_Index+1,1)) = 'C' and (substring(SWV_InputString,v_Index-1,1) in (' ','-') or v_Index=1) then
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index,1)) from v_Index for 1);
					--makes the 'C' lower case.
					v_OutputString := overlay(v_OutputString placing lower(substr(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
					--makes the letter after the 'c' upper case
					v_OutputString := overlay(v_OutputString placing upper(substr(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
					--we took care of the char acfter 'c' (we handled 2 letters instead of only 1 as usual), so we need to advance.
					v_Index := v_Index+1;
				end if;
			end if;
		end if;

		v_Index := v_Index+1;
	end loop; 

	return coalesce(v_OutputString,'');
end;
$body$
language 'plpgsql'
volatile
called on null input
security invoker
cost 100;

/* Examples of funtionality
select * from Format_TitleCase('MR DOG BREATH');
select * from Format_TitleCase('each word, mcclure of this string:shall be transformed');
select * from Format_TitleCase(' EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
select * from Format_TitleCase('mcclure and others');
select * from Format_TitleCase('J & B ART');
select * from Format_TitleCase('J&B ART');
select * from Format_TitleCase('J&B ART J & B ART this''s art''s house''s problem''s 0''shay o''should work''s EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
*/