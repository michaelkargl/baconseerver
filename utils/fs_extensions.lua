require 'string_extensions'

-- @param relative_path <string>
-- @return <string> absolute path
function fs.resolve(path)
    local already_absolute = not string.startsWith(path, './') and not string.startsWith(path, '../')
    if already_absolute then
        return path
    end
    
    local working_dir = shell.dir()
    local absolute_path = '/'..fs.combine(working_dir, path)
    return absolute_path
end

-- @param absolute_file_path <string>
-- @param count <int> how many lines to read off the top
-- @return <iterator<string>> an iterator over the first n lines
function fs.head(absolute_file_path, count)
    local line_count = 0
    local line_iterator = io.lines(absolute_file_path)
    local iterate_entire_file = count < 0

    return function()
        line_count = line_count + 1
        local iterate_next_line = line_count <= count
        if (iterate_entire_file or iterate_next_line) then
            return line_iterator()
        else
            return nil
        end
    end
end