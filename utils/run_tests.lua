function test(test_file)
    shell.execute('/bsrocks.lua', 'exec', test_file)
end

test('./string_extensions.test.lua')
test('./fs_extensions.tests.lua')