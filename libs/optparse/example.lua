local OptionParser = require "optparse" . OptionParser

local opt = OptionParser(
  {
    usage="%prog [options] [gzip-file...]",
    version="foo 1.23",
    add_help_option=false,
    exit_fn=(function (error_code)
      -- This argument is not part of the original optparse librar!
      -- On CraftOS there is no `os.exit()` (https://tweaked.cc/module/os.html),
      -- so I added this param so we can mock it. 
      print("Mocked exit with status_code ", error_code)
    end)
  }
)
-- The `action` defines how optparse reads the command line values
-- https://docs.python.org/3/library/optparse.html#understanding-option-actions

-- store: when optparse sees the option string -f, it consumes the next argument and stores it in options.<dest>
-- store_true: when optparse sees the option string --force, it assigns a `true` value to options.<dest>

opt.add_option{
  "-h",
  "--help",
  action="store_true",
  dest="help",
  help="give this help"
}

opt.add_option{
  "-f",
  "--force",
  dest="force",
  action="store_true",
  help="force overwrite of output file"
}

opt.add_option{
  "-f",
  "--file",
  type="string",
  dest="file",
  action="store",
  help="provide a value"
}


local options, args = opt.parse_args()

if options.help then
  print "Help argument received"
end

if options.force then
  print 'Force argument received'
end

if options.file then
  print('File received: ', options.file)
end

if options.logfiles then
  print('Log files: ', options.logfiles)
end

for key, value in ipairs(args) do
  print(key, value)
end

