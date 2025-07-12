
local disks = {
    rx = '/disk',
    table_utils = '/disk4'
}

local Rx = require(disks.rx..'/rx');
require(disks.table_utils..'/lib/table_utils')

_G.hw_left  = Rx.Subject.create();
_G.hw_right = Rx.Subject.create();

function half_word_to_string(half_word)
    local hw_str = string.format('%i %i %i %i',
        half_word[1],
        half_word[2],
        half_word[3],
        half_word[4]
    );
    
    print('HW: '..hw_str);
    return hw_str;
end

local function await_signals(protocol)
    local protocol_name = ('redstone_signals_%s'):format(protocol);
    
    -- print(('Awaiting signals for: %s'):format(protocol_name));
    local id, message = rednet.receive(protocol_name);
    
    if id == nil then
        print("Timeout reached...");
        return nil
    end
    
    print(('%i: Received message %s %s %s %s'):format(
        id, 
        message.back, 
        message.front,
        message.left,
        message.right
    ));
    return message;
end


local function signals_to_half_word(signals)
    return {
         signals['top'],
         signals['left'],
         signals['front'],
         signals['right']
   };
end

local function signals_to_word(signals_left, signals_right)
   return {
       signals_left[1],
       signals_left[2],
       signals_left[3],
       signals_left[4],
       signals_right[1],
       signals_right[2],
       signals_right[3],
       signals_right[4]
   };
end

function await_left_word()
    while true do
        local signals = await_signals('left');
        if signals ~= nil then
            local half_word = signals_to_half_word(signals);
            
            print('left '..half_word_to_string(half_word));
            _G.hw_left(half_word);
        end
    end
    
end


function await_right_word()
    while true do
        local signals = await_signals('right');
        if signals ~= nil then
            local half_word = signals_to_half_word(signals);
            
            print('right: '..half_word_to_string(half_word));        
            _G.hw_right(half_word);
        end
    end
end



-- print(_G.hw_left);
-- print(_G.hw_right);
Rx.Observable.combineLatest(
    _G.hw_left,
    _G.hw_right,
    function(left, right)
        -- print(left);
        -- print(right);
        return {
            left = left,
            right = right
        };
    end
):subscribe(function(t)
    if t.left ~= nil and t.right ~= nil then
        print("Table")
        print_table(t);
        --print("Table Left");
        --print_table(t.left);
        --print("Table Right");
        --print_table(t.right);
        
        local word = signals_to_word(t.left, t.right);
        print_table(word);        
        rednet.broadcast(word, 'word');
        
        -- TODO: print both tables to see whats in there
    end
    
    --hw_left = signals_to_half_word(t.left);    
   -- print(half_word_to_string(hw_left));
    
    --hw_right = signals_to_half_word(t.right);
    --print(half_word_to_string(hw_right));

        -- word = signals_to_word(hw_left, hw_right);
end);
-- :filter(function(tuple)
--    return true;
--    print('filtering: '..tuple.left.. ' '.. tuple.right);
--    return tuple.left ~= nil and tuple.right ~= nil
--end):map(function(tuple)
--    print('mapping');
--    return signals_to_word(tuple.left, tuple.right);
-- end)
-- :subscribe(function(word)
 --   print("Broadcasting "..word..'to '.."'word'");
  --  rednet.broadcast(word, 'word');
-- end);

monitor_id,clk_signal_id,modem_id=...

rednet.open(modem_id);

parallel.waitForAll(
    await_left_word,
    await_right_word
);

--rednet.close(modem_id);
