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

        it('returns the input path if already absolute', function()
            local absolute_path = fs.resolve('./fs_extensions.tests.lua')
            local actual = fs.resolve(absolute_path)
            assert.is.equal(absolute_path, actual)
        end)
    end)    
end)