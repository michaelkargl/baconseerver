require 'usingUtils'
require 'stopwatch'
require 'numberUtils'

if(#(arg) < 2) then
   print('Arguments are missing.\n');
   print('pinger --computerId <targetComputerId>\n');
   return 1
end

local targetComputerId=tonumber(arg[2]);
local pingTimeoutInSeconds = 3;
local pingIntervalInSeconds = 1;
local peripherals = { modem = 'back' };
local protocols = {
   getPingProtocol = function(computerId) return string.format('pc/%s/ping', computerId) end,
   getPongProtocol = function() return string.format('pc/%i/pong', os.getComputerID()) end
};


-- @Synopsis sends a single ping request to the designated destination
-- @Param computerId <number>
-- @Returns <void>
local function ping(computerId)
   local message = os.epoch('utc');
   local protocol = protocols.getPingProtocol(computerId);
   --print(("> Ping (%s)"):format(pingTime));
   rednet.send(computerId, message, protocol);
end


-- @Synopsis awaits a single pong request
-- @Param timeoutInSeconds <number | nil> waits for n seconds (or infinite if nil) for a pong response
-- @Returns true if pong received in time
-- @Returns false if ping request ran into timeout
local function awaitPong(timeoutInSeconds)
   local _computerId, pongResponse, _protocol = rednet.receive(protocols.getPongProtocol(), timeoutInSeconds);
   --print(string.format('< Pong %s (%s): %s', computerId, protocol, pongResponse));
   return pongResponse and true or false;
end


-- @Synopsis issues a single ping/pong loop
-- @Description A two-step process is triggered:
--              1. Send ping request to target computer
--              2. Await a pong requet from target computer
--              3. Print request summary line to stdout
-- @Returns true if ping-pong request was executed successfully
-- @Returns false if ping-pong request ran into timeout
local function processPingPongRequest(computerId, timeoutInSeconds)
   local pongReceived = false;
   local seconds = stopExecutionTime(function()
      ping(computerId);
      pongReceived = awaitPong(timeoutInSeconds)
   end);

   if(not pongReceived) then
      print(string.format('> ping-pong to computer %i timed out after %is', computerId, timeoutInSeconds));
      return false;
   end

   print(string.format('> ping-pong to computer id=%i took %i s', computerId, seconds));
   return true;
end


-- @Synopsis issues ping-pong requests to a given computer until manually stopped
-- @Description A two-step process is triggered:
--              1. Send ping request to target computer
--              2. Await a pong requet from target computer
--              3. Print request summary line to stdout
-- @Param id <number> the target computer id to ping
-- @Param pingCount <number | nil> pings the computer exactly n times. Defaults to maxUnsignedInteger if left out.
-- @Returns <void>
local function pingComputer(id, pingCount)
   pingCount = pingCount or maxUnsignedInteger;

   print(string.format('Pinging computer %s %u times', id, pingCount));
   local timeoutReplacesSleep = pingTimeoutInSeconds >= pingIntervalInSeconds;

   for iteration = pingCount, 1, -1 do
      usingRednet(peripherals.modem, function ()
         io.write(string.format('%u ', iteration));

         local requestSucceeded = processPingPongRequest(id, pingTimeoutInSeconds);
         local requiresSleep = requestSucceeded or not timeoutReplacesSleep;
         if(requiresSleep) then
            sleep(pingIntervalInSeconds);
         end
      end);
   end
end

pingComputer(targetComputerId);