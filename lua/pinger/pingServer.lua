require 'async_send_receive'
require 'usingUtils'

local targetComputerId=os.getComputerID()
local peripherals = {
    modem = 'left',
    status_light = 'top'
};

local protocols = {
    ping = string.format('pc/%s/ping', targetComputerId),
    getPongProtocol = function(requestComputerId)
        return string.format('pc/%s/pong', requestComputerId)
    end
};


local function pingpongMmessage(protocols, peripherals)
    local function receivePing(await_fn)
        asyncReceiveMessage(protocols.ping, await_fn);
    end
    
    local function pongMessage(computer_id, message)
        sendMessage(computer_id, message, protocols.getPongProtocol(computer_id));
    end
    
    local function setStatusLight(signalStrength)
        -- print(('Signaling %i'):format(signalStrength));
        redstone.setAnalogOutput(
            peripherals.status_light,
            signalStrength
        );    
    end
    
    local function statusLightDecorator(fn)
        return function (...)
            setStatusLight(15);
                sleep();
                fn(...);
            setStatusLight(0);
        end
    end
    
    receivePing(
        statusLightDecorator(pongMessage)
    );
end


print(string.format('Ping server running...'));
while true do
    usingRednet(peripherals.modem, function ()
        --print(os.date());
        pingpongMmessage(protocols, peripherals);
        --print();
    end);
end
