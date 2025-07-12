
-- Standard Lua uses 64-bit integers and double-precision (64-bit) floats, but you 
-- can also compile Lua so that it uses 32-bit integers and/or single-precision (32-bit) floats.
-- @Seealso: https://www.lua.org/manual/5.3/manual.html

-- math.pow(2, 32) - 1;
maxUnsignedInteger = 4294967295

-- maxUnsignedInteger / 2
maxIntegerNumber = 2147483647;