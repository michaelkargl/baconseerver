compare_util_disk='/disk3'
require(compare_util_disk..'/compare');

protocol = ...
modem_id = 'back';
clk_signal_id = 'bottom';
rednet_modem = rednet.open(modem_id);
prev_signals = {};

print("Using protocol "..protocol);

function get_redstone_signals()
    signals = {}
    
    for i,side in pairs(redstone.getSides()) do
        signals[side] = redstone.getAnalogInput(side);
    end
    
    return signals;
end

function clone_table_shallow(table)
    local clone = {};
    for key, value in pairs(table) do
        clone[key] = value;
    end
    
    return clone;
end

function compare_signals(left, right)
    left  = clone_table_shallow(left);
    right = clone_table_shallow(right);
    
    -- ignore clk signal when comparing
    left[clk_signal_id] = -1;
    right[clk_signal_id] = -1;

    return deepcompare(left, right);    
end


while true do
   os.pullEvent('redstone');
   signals = get_redstone_signals();
   
   clk_signal_received = signals[clk_signal_id] > 0;
   if clk_signal_received then
        if not compare_signals(signals, prev_signals) then
            print(signals);
            rednet.broadcast(signals, protocol);   
        
            prev_signals = signals;
        end
    end
end

rednet.close(modem_id);

