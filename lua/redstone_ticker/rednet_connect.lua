local rednetConnect = {};

-- @summary runs a given function in a scope where
--          rednet is available
-- @desc 1. opens rednet on all connected modems,
--       2. runs given function
--       3. closes rednet for all modems
-- @param func () => void
-- @return void
function rednetConnect.usingRednet(func)
  peripheral.find("modem", rednet.open);
     func();
  peripheral.find("modem", rednet.close);   
end;

return rednetConnect;
--usingRednet(function()
--    local id, message = rednet.receive();
--    print(("Computer %d sent message %s"):format(id, message));
--end); 
