require("assert_utils")

-- Summary: Executes and asserts a given function
-- Example: ltassert(function() return 1 == 2; end);
function lassert(func) lok(Assert(func)); end

-- Asserts if two tables are pointing to the same reference
function ltsame(t1, t2) lok(Assert_same(t1, t2)); end

-- Asserts if an input is a number
function lisnumber(input) lok(Assert_number(input)); end