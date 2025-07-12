require('compare')

function assert_equal(expected, actual, message)
    if expected ~= actual then
        local error_msg = message or string.format(
            'Expected values %s and %s to be equal.',
            expected, actual
        );
        error(error_msg);
    end
    return true;
end

function assert_true(actual, message)
    return assert_equal(true, actual, message);
end

function assert_false(actual, message)
    return not assert_equal(false, actual, message);
end


assert_false(deepcompare(1,nil));
assert_true(deepcompare(nil, nil));
assert_true(deepcompare(12, 12));
assert_false(deepcompare(1,nil,{}));
assert_true(deepcompare({a=12},{a=12}));
assert_true(deepcompare({a={a2={a3=12}}},{a={a2={a3=12}}}))
assert_false(deepcompare({a={a2={a3=12}}},{a={a2={a3=12}},b=3}))
print("Passed");	
