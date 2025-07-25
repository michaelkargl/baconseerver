--[[

LUA MODULE

  pythonic.optparse - Lua-based partial reimplementation of Python's
      optparse [2-3] command-line parsing module.

SYNOPSIS

  local OptionParser = require "pythonic.optparse" . OptionParser
  local opt = OptionParser{usage="%prog [options] [gzip-file...]",
                           version="foo 1.23", add_help_option=false}
  opt.add_option{"-h", "--help", action="store_true", dest="help",
                 help="give this help"}
  opt.add_option{
    "-f", "--force", dest="force", action="store_true",
    help="force overwrite of output file"}

  local options, args = opt.parse_args()

  if options.help then opt.print_help(); os.exit(1) end
  if options.force then print 'f' end
  for _, name in ipairs(args) do print(name) end
      
DESCRIPTION

  This library provides a command-line parsing[1] similar to Python optparse [2-3].

  Note: Python also supports getopt [4].

STATUS
  
  This module is fairly basic but could be expanded.
  
API

  See source code and also compare to Python's docs [2,3] for details because
  the following documentation is incomplete.
  
  opt = OptionParser {usage=usage, version=version, add_help_option=add_help_option}
  
    Create command line parser.
  
  opt.add_options{shortflag, longflag, action=action, metavar=metavar, dest=dest, help=help}
  
    Add command line option specification.  This may be called multiple times.
 
  opt.parse_args() --> options, args
  
    Perform argument parsing.
 
DEPENDENCIES

  None (other than Lua 5.1 or 5.2)
  
REFERENCES

  [1] http://lua-users.org/wiki/CommandLineParsing
  [2] http://docs.python.org/lib/optparse-defining-options.html
  [3] http://blog.doughellmann.com/2007/08/pymotw-optparse.html
  [4] http://docs.python.org/lib/module-getopt.html

LICENSE

  (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)

 --]]

 local M = {_TYPE='module', _NAME='pythonic.optparse', _VERSION='0.3.20111128'}
 
local ipairs = ipairs
local unpack = unpack
local io = io
local table = table
local os = os
local arg = arg


local function OptionParser(t)
  local usage = t.usage
  --local version = t.version

  local o = {}
  local option_descriptions = {}
  local option_of = {}

  function o.fail(s) -- extension
    io.stderr:write(s .. '\n')
    t.exit_fn(1)
  end

  function o.add_option(optdesc)
    option_descriptions[#option_descriptions+1] = optdesc
    for _,v in ipairs(optdesc) do
      option_of[v] = optdesc
    end
  end
  function o.parse_args()
    -- expand options (e.g. "--input=file" -> "--input", "file")
    local arg = {unpack(arg)}
    for i=#arg,1,-1 do local v = arg[i]
      local flag, val = v:match('^(%-%-%w+)=(.*)')
      if flag then
        arg[i] = flag
        table.insert(arg, i+1, val)
      end
    end

    local options = {}
    local args = {}
    local i = 1
    while i <= #arg do local v = arg[i]
      local optdesc = option_of[v]
      if optdesc then
        local action = optdesc.action
        local val
        if action == 'store' or action == nil then
          i = i + 1
          val = arg[i]
          if not val then o.fail('option requires an argument ' .. v) end
        elseif action == 'store_true' then
          val = true
        elseif action == 'store_false' then
          val = false
        end
        options[optdesc.dest] = val
      else
        if v:match('^%-') then o.fail('invalid option ' .. v) end
        args[#args+1] = v
      end
      i = i + 1
    end
    if options.help then
      o.print_help()
      t.exit_fn()
    end
    if options.version then
      io.stdout:write(t.version .. "\n")
      t.exit_fn()
    end
    return options, args
  end

  local function flags_str(optdesc)
    local sflags = {}
    local action = optdesc.action
    for _,flag in ipairs(optdesc) do
      local sflagend
      if action == nil or action == 'store' then
        local metavar = optdesc.metavar or optdesc.dest:upper()
        sflagend = #flag == 2 and ' ' .. metavar
                              or  '=' .. metavar
      else
        sflagend = ''
      end
      sflags[#sflags+1] = flag .. sflagend
    end
    return table.concat(sflags, ', ')
  end

  function o.print_help()
    io.stdout:write("Usage: " .. usage:gsub('%%prog', arg[0]) .. "\n")
    io.stdout:write("\n")
    io.stdout:write("Options:\n")
    local maxwidth = 0
    for _,optdesc in ipairs(option_descriptions) do
      maxwidth = math.max(maxwidth, #flags_str(optdesc))
    end
    for _,optdesc in ipairs(option_descriptions) do
      io.stdout:write("  " .. ('%-'..maxwidth..'s  '):format(flags_str(optdesc))
                      .. optdesc.help .. "\n")
    end
  end
  if t.add_help_option == nil or t.add_help_option == true then
    o.add_option{"--help", action="store_true", dest="help",
                 help="show this help message and exit"}
  end
  if t.version then
    o.add_option{"--version", action="store_true", dest="version",
                 help="output version info."}
  end
  return o
end


M.OptionParser = OptionParser


return M

