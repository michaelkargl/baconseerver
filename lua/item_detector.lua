local _,modem_id = ...

function using_rednet(modem_id, fn)
    rednet.open(modem_id);
    fn();
    rednet.close(modem_id);
end

function send_item_infos(infos)
    rednet.broadcast(infos, 'block_infos/floor');
end

while true do
    using_rednet(modem_id, function()
        block_detected, infos = turtle.inspectDown();
        send_item_infos(infos);
    end);
    sleep(1);
end

