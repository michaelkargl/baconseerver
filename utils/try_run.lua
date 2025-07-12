local function _try_run(script, ...)
   io.write(string.format("Try run %s: ", script))
   if not fs.exists(script) then
      print("missing")
      return
   end

   print("running")
   shell.run(script, ...)
end

--try_run('/disk3/bit_sensor.lua', 'redstone_signals_left');

return {
   try_run = _try_run
}
