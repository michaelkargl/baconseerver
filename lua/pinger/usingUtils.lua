
function usingRednet(modemId, fn)
    rednet.open(modemId);
       fn();
    rednet.close(modemId);
 end