' Roku system screensaver entry point (manifest: screensaver_title).
' Roku closes the screen when the user presses a key. Roku calls this without
' arguments; Main passes its launch args when previewing (tools\relaunch.ps1 -Screensaver).
sub RunScreenSaver(params = invalid as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("ScreensaverScene")
    screen.show()

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then return
    end while
end sub
