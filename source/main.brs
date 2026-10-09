' App entry point. Creates MainScene and keeps the channel alive until it closes.
sub Main(args as dynamic)
    applyLaunchSettings(args)

    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.show()
    scene.observeField("exitApp", port)

    while true
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if msgType = "roSGNodeEvent"
            if msg.getField() = "exitApp" and msg.getData() = true then return
        end if
    end while
end sub

' Dev convenience: sideloading wipes the registry, so tools\relaunch.ps1 passes
' serverUrl and apiKey (from .env) as ECP launch parameters to avoid retyping them.
sub applyLaunchSettings(args as dynamic)
    if type(args) <> "roAssociativeArray" then return
    if args.serverUrl = invalid or args.apiKey = invalid then return
    upsertProfile("", normalizeServerUrl(args.serverUrl), args.apiKey)
    logDebug("settings applied from launch parameters")
end sub
