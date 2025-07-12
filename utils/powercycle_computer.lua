local disks = {
    rx = '/disk'
}

Rx = require(disks.rx..'/rx');

input_pin_id = ...

computer_ids = {
    'computer_8',
    'computer_12',
    'computer_13',
    'computer_14',
    'computer_17'
}

computers = {}
for i,id in pairs(computer_ids) do
    computers[id] = peripheral.wrap(id)
end

function toggleComputerStates(computers, state)
    for id, computer in pairs(computers) do
        if state then
            print("Turning on computer "..id);
            if not computer.isOn() then
                computer.turnOn();
            else 
                print(id.." already on"); 
            end
        else
            print("Turning off computer "..id);
            if computer.isOn() then
                computer.shutdown();
            else
                print(id.." already off");
            end
        end
    end
end

rxPowerSignal = Rx.Subject.create()
rxPowerSignal
    :filter(function(s)
        return type(s) == 'number'; 
    end)
    :distinctUntilChanged()
    :subscribe(function(s)
        print("Signal changed "..s);
        toggleComputerStates(computers, s > 0);
    end);

while true do
    os.pullEvent('redstone');
    rxPowerSignal(
        redstone.getAnalogInput(input_pin_id)
    );
end
