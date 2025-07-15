require 'string_extensions'

function fs.resolve(relative_path)
    local working_dir = shell.dir()
    local absolute_path = '/'..fs.combine(working_dir, relative_path)
    return absolute_path
end