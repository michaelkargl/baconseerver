-- this approach only returns the path the entry
-- script has been called with
-- cd /startup
-- ./autorun.lua -- ./
-- /startup/autorun.lua -- /startup/
scriptFilePath = arg[0];
scriptDirPath = scriptFilePath:match('.*/');

scriptFilePath = debug.getinfo(1).short_src;
scriptFilePath = debug.getinfo(1,"S").source:sub(2)

print('scriptPath: '..scriptFilePath);
print('dirPath: '..scriptDirPath);
