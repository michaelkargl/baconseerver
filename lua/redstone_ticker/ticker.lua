
-- @summary invokes a callback in a given interval
-- @param intervalInSeconds: number
-- @param count: number how often to tick (use negative value for infinite loop)
-- @param callbackFn: (counter:number) => void
-- @param cancelationRequestedFn: () => boolean
-- @example tick(1, 3, function(i) print(i); end)
function tick(interval, count, callbackFn, cancelationRequestedFn)
    count = count or -1;
    cancelationRequestedFn = cancelationRequestedFn or function() return false end
    
    local counter = 0;
    local infiniteLoop = count < 0
    repeat
        callbackFn(counter);
        os.sleep(interval);
        counter = counter + 1;
        
        local counterExceeded = not infiniteLoop and counter >= count;
    until(counterExceeded or cancelationRequestedFn());
end

-- tick(1, 3, function(i) print(('Tick %i'):format(i)) end);
