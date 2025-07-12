
-- @synopsis    returns a grouped table of file items
-- @description groups file items by type
-- @example     get_child_items('/')
-- @returns     {leafs = {}, containers = {}}
function get_child_items(path)
    local items = fs.list(path);
    local grouped_items = {};
    grouped_items[true] = {}
    grouped_items[false] = {}
    
    for i,item in pairs(items) do
        item_path = fs.combine(path, item);
        local is_directory = fs.isDir(item_path);
        --print(string.format("%s %s", path, is_directory));
        
        table.insert(grouped_items[is_directory], item_path);
    end

    --print("Containers: "..#grouped_items[true]);
    --print("Leafs: "..#grouped_items[false]);
        
    return {
        containers = grouped_items[true],
        leafs = grouped_items[false]
    };
end

-- @summary find all directory items in path
-- @description convenience function to @see(get_child_items)
-- @returns { '/dir1', '/dir2' }
function get_child_directories(path)
    return get_child_items(path).containers;
end

-- @summary find all file items in path
-- @description convenience function to @see(get_child_items)
-- @returns {'/file1', '/file2'}
function get_child_files(path)
    return get_child_items(path).leafs;
end

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


-- @synopsis pretty print childitems in path
-- @example list_child_items('/autorun')
-- @returns void
-- @outputs dir1
--           dir2
--            file1
function list_child_items(path, recurse, _level)
    recurse = recurse or false;
    _level = _level or 0;
    if not fs.isDir(path) or not fs.exists(path) then
     error("Unable to list items of path. "..
           "Make sure it is an existing directory\n"..
           "Path: "..path);
    end
    
    items = get_child_items(path);
    
    --_indent_string("Leafs", _level);        
    print_table(items.leafs, _level);
    
    for i,dir in pairs(items.containers) do
        dir_path = fs.combine(path, dir);
        _indent_string(dir_path, _level);

        if recurse then
            list_child_items(
                dir_path,
                recurse,
                _level + 1
            );
        end
    end
end

-- list_child_items("/", true);
