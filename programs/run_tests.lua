function test(test_file)
    shell.execute('/bsrocks.lua', 'exec', test_file)
end

test('./cat.tests.lua')