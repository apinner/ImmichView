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

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then return
    end while
end sub

#if DEV
' Dev builds only (Roku doesn't allow Main in a screensaver): launching the sideloaded
' screensaver (tools\relaunch.ps1 -Screensaver) shows it straight away, signed in from the
' launch parameters because sideloading wiped the registry.
sub Main(args as dynamic)
    applyDevLaunchSettings(args)
    RunScreenSaver(args)
end sub
#end if
