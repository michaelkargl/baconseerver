require '/disk/async_send_receive'

local peripherals = {
    modem = 'left'
}

rednet.open(peripherals.modem);

function log_pong(computer_id, message, protocol)
    print(('[%s/%s] > %s'):format(
        computer_id, message, protocol
    ));
end

while true do
    print(os.date());
       async_receive_message('pong', log_pong);
    print();
end

rednet.close(peripherals.modem);
