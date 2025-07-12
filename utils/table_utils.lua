-- @synopsis repeats a string n times
-- @example _repeat_string('x', 3)
-- @returns 'xxx'
local function _repeat_string(string, times)
    for i = 0,times,1 do
        io.write(string);
    end
end

-- @synopsis indents a string
-- @example _indent_string('indent_me', 4)
-- @returns void
-- @outputs "    indent_me"
local function _indent_string(string, level)
    _repeat_string(' ', level);
    print(("%s"):format(string));
end

-- @synopsis     prints a table to stdout
-- @description  each element is indented
--               according to it sdepth
-- @param table  table to traverse and print
-- @param _depth internal value used to store
--               the level of recursion. This
--               parameter is set internally and
--               must be omitted
-- @example      print_table({a={b={c=132}}})
function print_table(tbl, _depth)
    _depth = _depth or 0
    tbl = tbl or {}

    for key,value in pairs(tbl) do                        
        if type(value) == 'table' then
            print_table(value, _depth + 1);            
        else
            _indent_string(value, _depth);
        end
    end
end

