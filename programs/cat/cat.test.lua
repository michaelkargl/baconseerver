package.path = package.path .. ";../../utils/?.lua"

require "fs_extensions"

local cat = fs.resolve('./cat.lua')
local file_to_cat = cat

shell.run(cat, file_to_cat)