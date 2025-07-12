
-- https://luarocks.org/modules/kikito/ansicolors
-- luarocks install ansicolors
-- bsrocks exec example.lua

local c = require 'ansicolors'

-- black red green yellow blue magenta cyan white
print(c('%{blackbg}hello'))
print(c('%{cyanbg}hel%{reset}lo'))
print(c('%{bright bluebg underline}hello'))
print(c('%{hidden yellowbg}hello'))
print(c('%{hidden greenbg}hello'))
print(c('%{hidden magentabg}hello'))
print(c('%{hidden cyanbg}hello'))
print(c('%{hidden whitebg}hello'))
print('text without color')