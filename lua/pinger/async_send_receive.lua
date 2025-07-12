-- @Synopsis: awaits a  single message following a certain protocol
-- @Description: waits for an input message following a 
--               specific protocol / topic and triggers a callback upon receipt.
-- @Parameter protocol <string>: The message topic to subscribe onto
-- @Parameter await_fn <Action<number, string, string>>:  message received callback
-- @Returns <void>
function asyncReceiveMessage(protocol, await_fn)
    -- print(('Awaiting %s messages...'):format(protocol));
    computer_id, message, protocol = rednet.receive(protocol);
    --print(('[%s/%s] > %s'):format(computer_id, protocol, message));
    
    await_fn(computer_id, message, protocol);    
end

function sendMessage(computerId, message, protocol)
    --print(('[%s/%s] < %s'):format(computerId, protocol, message));
    rednet.send(computerId, message, protocol);
end

