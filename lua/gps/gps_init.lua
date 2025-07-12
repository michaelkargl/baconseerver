local GpsInit = {} 

function GpsInit.host(name, x, y, z)
   print(('hosting gps %s at pos %d,%d,%d'):format(name,x,y,z));
   shell.run("gps","host", x, y, z);
end

return GpsInit;
