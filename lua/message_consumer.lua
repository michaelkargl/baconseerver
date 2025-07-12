monitor = peripheral.wrap("right")
monitor.setBackgroundColor(0xfff)

rednet.open("top")

function get_monitor_size()
    size = { monitor.getSize() }
    return {
        x = size[1],
        y = size[2]
    }
end

function print_monitor(message)
    monitor.scroll(-1)
    monitor.setCursorPos(1,1)

    monitor.write(message)
    sleep() -- give monitor time to render
end

local sender_id, message
repeat
   print("waiting...")
   sender_id, message = rednet.receive()
   
   print_monitor(message)
   -- log("[%s]: %s", sender_id, message)
until message == "fin"

