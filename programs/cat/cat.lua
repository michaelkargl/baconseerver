local args = { ... }
local status_codes = {
    OK = 0,
    INVALID_ARGUMENT_COUNT = 2,
    FILE_NOT_FOUND = 3,
    ERROR = 1,
}


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

local filePath = args[1]

if ( not fs.exists(filePath) ) then
    print("File ["..filePath.. "] not found.")
    return status_codes.FILE_NOT_FOUND
end

if ( fs.isDir(filePath) ) then
    print("["..filePath.."] is not a file.")
    return status_codes.FILE_NOT_FOUND
end

if ( filePath)


print(filePath)
print(#args)