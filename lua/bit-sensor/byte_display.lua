monitor_id, modem_id = ...

local disks = {
   monitor_utils = '/disk2',
   rx            = '/disk',
   table_utils   = '/disk4'
}

require(disks.table_utils..'/lib/table_utils');
require(disks.monitor_utils..'/monitor_utils');
Rx = require(disks.rx..'/rx');


function await_signals(protocol_name)
    
    -- print(('Awaiting signals for: %s'):format(protocol_name));
    local id, message = rednet.receive(protocol_name);
    
    if id == nil then
        print("Timeout reached...");
        return nil
    end
    
    -- print(('%i: Received message %s'):format(id, message))
    return message;
end

_G._word = Rx.Subject.create();
_G._word
 :distinctUntilChanged()
 :filter(function(word) return #word == 8 end)
 :map(function(word)
     return ('%s %s %s %s %s %s %s %s'):format(
        word[1], word[2], word[3], word[4],
        word[5], word[6], word[7], word[8]
     );
 end):subscribe(function(word)
    print("word "..word);
    write_monitor(monitor, word);
 end);

monitor = init_monitor(monitor_id);
rednet.open(modem_id);

while true do
    print('Waiting for words...');
    local word = await_signals('word')
    
    -- print('Received:');
    -- print_table(word, 1);
    
    if word ~= nil then
        _G._word(word);
    end
    -- sleep(0.1)
end

rednet.close(modem_id);
