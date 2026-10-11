' Entry point of the ImmichView Screensaver app (manifest.screensaver), a separate channel
' from ImmichView because Roku only allows screensavers as standalone apps. It reads the
' users ImmichView saved: both apps are packaged with the same developer ID, so they share
' a registry. Roku closes the screen when the user presses a key.
sub RunScreenSaver(params = invalid as dynamic)
    if params <> invalid then logDebug("screensaver preview")
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("ScreensaverScene")
    screen.show()
    ' The screensaver holds only two photos at a time, so warnings are just logged.
    memory = startMemoryMonitor(port)

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then return
        percent = memoryWarningPercent(msg, memory)
        if percent <> invalid then logDebug("memory warning: " + percent.ToStr() + "%")
    end while
end sub
