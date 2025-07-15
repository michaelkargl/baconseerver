
-- summary: Executes and asserts the functions truthyness\
-- example: assert(function() return 1 == 2 end)\
-- returns: boolean
function Assert(func)
    return type(func) == 'function' and func()
end

-- summary: Tests if an input is truthy
-- parameter predicate: a boolean input
-- returns: boolean
function Assert_truthy(input)
    return Assert(function()
        return type(input) == "boolean" and input
    end);
end

-- summary: Tests if two inputs are the same
-- returns: boolean
function Assert_same(o1, o2)
    return Assert(function()
        return o1 == o2;
    end);
end


--summary Tests if an input is a number
-- returns: boolean
function Assert_number(input)
    return Assert(function()
        return type(input) == "number"
    end)
end

