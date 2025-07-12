
function init_monitor(monitor_id)
    monitor = peripheral.wrap(monitor_id);

    
    monitor.setBackgroundColor(colors.black);
    monitor.setTextColor(0x100);
    monitor.clear();
    monitor.setCursorBlink(false);
    monitor.setCursorPos(1,1);
    
    return monitor;
end

function write_monitor(monitor, text)
   monitor.setCursorPos(3,3);
   monitor.clearLine();
   monitor.write(text);
end
