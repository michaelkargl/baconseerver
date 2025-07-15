require 'busted.runner'()
require 'fs_extensions'
require 'string_extensions'

describe('fs_extensions', function()
    describe('resolve', function()
        it('resolves "." to the current working directory', function()
            local actual = fs.resolve('./fs_extensions.tests.lua')
            assert.falsy(string.startsWith(actual, './'))
            assert.truthy(fs.exists(actual))
        end)

        it('resolves ".." to the parent working directory', function()
            local actual = fs.resolve('../utils/fs_extensions.tests.lua')
            assert.falsy(string.startsWith(actual, '../'))
            assert.truthy(fs.exists(actual))
        end)
    end)
end)