 require('ticker');
local Side = require('side');
local RednetConnect = require('rednet_connect');

-- @param side: Side
-- @returns true if signal present
-- @returns false if no signal present
function getRedstoneState(side)
    return redstone.getInput(side);
end

-- @summary sends a redstone pulse
-- @param direction: Side
function toggleRedstone(side)
    local toggleState = not getRedstoneState(side);
    redstone.setOutput(side, toggleState);
end

function publishRedstoneStateChange(state)
    RednetConnect.usingRednet(function()
        local topic = 'computer/'..os.getComputerID()..'/signal';
        
        print(('publishing to %s => %s'):format(topic, state));
        rednet.broadcast(state, topic);
    end);
end;

function main()
    local signalLengthInSeconds = 1
    local oneHourInSeconds = 3600;
    local outputSide = Side.Front;
   
    tick(signalLengthInSeconds, oneHourInSeconds, function(counter)
        io.write(('%i/%i '):format(counter, oneHourInSeconds));
        
        toggleRedstone(outputSide);
        publishRedstoneStateChange(
            getRedstoneState(outputSide)
        );

    end);
end


main();
