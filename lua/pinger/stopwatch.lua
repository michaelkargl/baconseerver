-- @Synopsis stops the execution time of a given function in milliseconds
-- @Param <Action> function whose execution time should be stopped
-- @Returns <number> milliseconds
function stopExecutionTime(fn)
    local startTime = os.epoch('utc');
    fn();
    local endTime = os.epoch('utc');
    
    return endTime - startTime;
 end