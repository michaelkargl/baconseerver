require 'string_extensions'
require 'busted.runner'()

describe("string_extensions", function()
    describe("string.startsWith", function()
        it("returns true if begins with the string", function()
            local actual = string.startsWith('test/123', 'test')
            assert.truthy(actual)
        end)

        it('returns false if it does not begin with the desired string', function()
            local actual = string.startsWith('test/123', 'unknown')
            assert.falsy(actual)
        end)
    end)

    describe('string.trimStart', function()
        it("cuts off string if it begins with it", function()
            local actual = string.trimStart('../directory', '../')
            assert.are.equal('directory', actual)
        end)

        it('returns the input string if not starting with the trim portion', function()
            local expected = '../directory'
            local actual = string.trimStart(expected, 'unknown')
            assert.are.equal(expected, actual)
        end)
    end)
end)