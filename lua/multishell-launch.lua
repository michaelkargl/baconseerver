local autorun_disk = '/disk4';
local lib_dir = autorun_disk..'/lib';
local autorun_dir = '/autorun'

require(lib_dir.."/"..'fs_list_dirs')

local scripts = get_child_files(autorun_dir);

for i,script in pairs(scripts) do
    print("Executing "..script);
    
    -- Multishell does not have access to APIs such as 'require' (see docs)
    -- so we have to cheat a little. Arguments are passed as objects so
    -- we can pass in whatever we need via args
    multishell.launch({123}, script, {
       require = require
    });
end

