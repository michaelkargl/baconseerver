package.path = package.path .. ";../../utils/?.lua"

require "fs_extensions"

local args = { ... }
local status_codes = {
    OK = 0,
    INVALID_ARGUMENT_COUNT = 2,
    FILE_NOT_FOUND = 3,
    ERROR = 1,
}

-- @return void
function print_help()
    print "Usage:"
    print "cat <file>"
end


if ( #args == 0 ) then
    print_help()
    return status_codes.INVALID_ARGUMENT_COUNT
end

if ( #args > 1 ) then
   print "Too many files received."
   print_help()
   return status_codes.INVALID_ARGUMENT_COUNT
end

local filePath = fs.resolve(args[1])

if ( not fs.exists(filePath) ) then
    print("File ["..filePath.. "] not found.")
    return status_codes.FILE_NOT_FOUND
end

if ( fs.isDir(filePath) ) then
    print("["..filePath.."] is not a file.")
    return status_codes.FILE_NOT_FOUND
end

for line in fs.head(filePath, -1) do
    print(line)
end