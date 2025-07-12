messageLimit = 250 --negative for infinity

rednet.open("top")

function send_message(msg)
   rednet.broadcast(msg)
   sleep()
end

function wait_for_redstone()
    print("Waiting for redstone signal")
    os.pullEvent("redstone")
end


while true do
    wait_for_redstone()

    count = 0
    repeat
       -- message = os.date("%H:%M:%S")
       message = ("%d"):format(os.epoch("local"))
       
       send_message(message)
       print(message)
       disks/15/RxLua-master-16edbf9f
       sleep()
       count = count + 1   
    until count == messageLimit
end

send_message("fin")
