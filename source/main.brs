' App entry point. Creates MainScene and keeps the channel alive until it closes.
sub Main(args as dynamic)
    #if DEV
        applyDevLaunchSettings(args)
    #end if

    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.show()
    scene.observeField("exitApp", port)

    ' Deep links: contentId/mediaType at launch, and roInput events while running.
    input = CreateObject("roInput")
    input.setMessagePort(port)
    deepLink = deepLinkFrom(args)
    if deepLink <> invalid then scene.deepLink = deepLink

    ' Memory warnings go to MainScene, which has the screens free what they can.
    memory = startMemoryMonitor(port)

    while true
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if msgType = "roSGNodeEvent"
            if msg.getField() = "exitApp" and msg.getData() = true then return
        else if msgType = "roInputEvent"
            if msg.isInput()
                deepLink = deepLinkFrom(msg.getInfo())
                if deepLink <> invalid then scene.deepLink = deepLink
            end if
        else
            percent = memoryWarningPercent(msg, memory)
            if percent <> invalid then scene.memoryWarning = Int(percent)
        end if
    end while
end sub

' { contentId, mediaType } when both are present, else invalid. contentId is an Immich asset ID.
function deepLinkFrom(params as dynamic) as dynamic
    if type(params) <> "roAssociativeArray" then return invalid
    if params.contentId = invalid or params.mediaType = invalid then return invalid
    return { contentId: params.contentId, mediaType: params.mediaType }
end function
