-- extend search paths
package.path = package.path .. ";../math_util/?.lua"
package.path = package.path .. ";minctest-lua/?.lua"
package.path = package.path ..";utils/?.lua"

require('math_util')
require("minctest")
require("assert_utils")
require("minctest_utils")

lrun("Assert same strings: minctest", function()
    lok('a' == 'a');
end);

lrun("Assert generic func: custom", function()
    local expected = 1123
    local actual = 1123
    lassert(function()
        return expected == actual
    end)
end);

lrun("Assert same table: custom", function()
    local t = {}
    ltsame(t, t);
end);

lrun("Assert sum returning number: custom", function()
    lisnumber(Sum(0, 1));
end);

lrun("Assert sum to return valid result", function()
    lequal(Sum(323, 7.23), 330.23);
end);




lresults(); --show results