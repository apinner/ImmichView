' Memory monitoring (required for certification from 1 October 2026). Roku sends
' roAppMemoryNotificationEvent when the app crosses 80/85/90/95% of its memory limit;
' devices without that get roDeviceInfoEvent low general memory events instead.
' Keep the returned object for as long as events are wanted.
function startMemoryMonitor(port as object) as object
    watchers = {}
    monitor = CreateObject("roAppMemoryMonitor")
    if monitor <> invalid
        monitor.SetMessagePort(port)
        watchers.monitor = monitor
        logDebug("memory limits " + FormatJson(monitor.GetChannelMemoryLimit()) + ", available " + monitor.GetChannelAvailableMemory().ToStr() + " KB")
        if monitor.EnableMemoryWarningEvent(true) then return watchers
    end if
    deviceInfo = CreateObject("roDeviceInfo")
    deviceInfo.SetMessagePort(port)
    deviceInfo.EnableLowGeneralMemoryEvent(true)
    watchers.deviceInfo = deviceInfo
    return watchers
end function

' For a message from the monitor's port: the memory use in percent of the app's limit
' (or 95 for a critical / 85 for a low general memory level), or invalid if the message
' isn't a memory event.
function memoryWarningPercent(msg as object, watchers as object) as dynamic
    msgType = type(msg)
    if msgType = "roAppMemoryNotificationEvent"
        percent = msg.GetInfo().memoryUsagePercent
        if percent = invalid and watchers.monitor <> invalid then percent = watchers.monitor.GetMemoryLimitPercent()
        return percent
    else if msgType = "roDeviceInfoEvent"
        level = msg.GetInfo().generalMemoryLevel
        if level = "critical" then return 95
        if level = "low" then return 85
    end if
    return invalid
end function
