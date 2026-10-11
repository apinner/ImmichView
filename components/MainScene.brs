sub init()
    m.top.backgroundUri = ""  ' the theme's default background image would hide backgroundColor
    m.top.backgroundColor = "0x24232FFF"
    m.screens = []
    m.global.addFields({ serverUrl: "", apiKey: "", mediaFilter: loadMediaFilter() })

    ' Short pause after "Connected as ..." so the confirmation is readable.
    m.connectedTimer = CreateObject("roSGNode", "Timer")
    m.connectedTimer.duration = 1.5
    m.connectedTimer.observeField("fire", "onConnectedTimer")
    m.top.appendChild(m.connectedTimer)

    ' Launch beacons (certification): AppLaunchComplete once Home is ready or deep-linked
    ' content is showing; AppDialog* around the sign-in screen if it's shown at launch.
    m.launchCompleteSent = false
    m.launchDialogOpen = false
    m.homeReady = false
    m.pendingDeepLink = invalid

    applySettings(loadSettings())
    first = launchScreen()
    resetTo(first)
    if first <> "HomeScreen"
        ' Sign-in or user selection before Home: certification's AppDialog beacons.
        m.top.signalBeacon("AppDialogInitiate")
        m.launchDialogOpen = true
    end if
end sub

' Sign-in when there are no users; Who's watching when there are several, when the only user
' has a PIN, or when none is active; otherwise straight to Home.
function launchScreen() as string
    profiles = loadProfiles().profiles
    if profiles.Count() = 0 then return "LoginScreen"
    active = loadSettings()
    if profiles.Count() >= 2 or not hasSettings(active) or profileHasPin(active) then return "ProfilePickerScreen"
    return "HomeScreen"
end function

sub endLaunchDialog()
    if not m.launchDialogOpen then return
    m.launchDialogOpen = false
    m.top.signalBeacon("AppDialogComplete")
end sub

sub onProfileChosen()
    endLaunchDialog()
    applySettings(loadSettings())
    resetTo("HomeScreen")
end sub

sub sendLaunchComplete()
    if m.launchCompleteSent then return
    m.launchCompleteSent = true
    m.top.signalBeacon("AppLaunchComplete")
    logDebug("AppLaunchComplete")
end sub

sub onHomeReady(event as object)
    if not event.getData() then return
    m.homeReady = true
    if m.pendingDeepLink <> invalid
        link = m.pendingDeepLink
        m.pendingDeepLink = invalid
        openDeepLink(link)
    else
        sendLaunchComplete()
    end if
end sub

' ---- Deep links (contentId = Immich asset ID) ----

sub onDeepLink()
    link = m.top.deepLink
    logDebug("deep link " + link.mediaType + " " + link.contentId)
    if m.homeReady
        openDeepLink(link)
    else
        m.pendingDeepLink = link  ' opened once Home is ready (after sign-in if needed)
    end if
end sub

sub openDeepLink(link as object)
    if not CreateObject("roRegex", "^[0-9a-fA-F-]{36}$", "").IsMatch(link.contentId)
        deepLinkFailed("not an asset ID")
        return
    end if
    m.deepLinkTask = startApiRequest(currentSettings(), "GET", "/api/assets/" + link.contentId, "onDeepLinkAsset")
end sub

sub onDeepLinkAsset(event as object)
    resp = event.getData()
    m.deepLinkTask = invalid
    if not resp.ok
        deepLinkFailed("asset lookup " + resp.status.ToStr())
        return
    end if

    ' Show it on top of Home, whatever was open before.
    while m.screens.Count() > 1
        popScreen()
    end while
    asset = resp.data
    duration = asset.duration
    if duration = invalid then duration = 0
    item = { assetId: asset.id, ratio: 1.0, isVideo: asset.type = "VIDEO", durationMs: duration }
    if item.isVideo
        player = pushScreen("VideoPlayer", { asset: item })
        if m.launchCompleteSent
            return
        end if
        player.observeField("playbackStarted", "onDeepLinkPlaybackStarted")
    else
        source = CreateObject("roSGNode", "AssetListSource")
        source.assets = [item]
        pushScreen("PhotoViewer", { open: { timeline: source, index: 0 } })
        sendLaunchComplete()
    end if
end sub

sub onDeepLinkPlaybackStarted()
    sendLaunchComplete()
end sub

' Invalid or inaccessible content: stay on Home, as certification expects.
sub deepLinkFailed(reason as string)
    logDebug("deep link ignored: " + reason)
    sendLaunchComplete()
end sub

sub applySettings(settings as object)
    m.global.serverUrl = settings.serverUrl
    m.global.apiKey = settings.apiKey
end sub

' ---- Screen stack ----

' params: field values set on the new screen before it is shown, e.g. { source: {...} }
function pushScreen(name as string, params = invalid as dynamic) as object
    screen = CreateObject("roSGNode", name)
    screen.observeField("navigate", "onNavigate")
    if name = "LoginScreen" then screen.observeField("connectedUser", "onConnected")
    if name = "HomeScreen"
        m.homeReady = false
        screen.observeField("ready", "onHomeReady")
    end if
    if screen.hasField("profilesChanged") then screen.observeField("profilesChanged", "onProfilesChanged")
    if screen.hasField("profileChosen") then screen.observeField("profileChosen", "onProfileChosen")
    if screen.hasField("done") then screen.observeField("done", "onScreenDone")
    if params <> invalid then screen.update(params)

    if m.screens.Count() > 0 then m.screens.Peek().visible = false
    m.top.appendChild(screen)
    m.screens.Push(screen)
    screen.setFocus(true)
    logDebug("push " + name)
    return screen
end function

sub popScreen()
    screen = m.screens.Pop()
    m.top.removeChild(screen)
    if m.screens.Count() > 0
        top = m.screens.Peek()
        top.visible = true
        top.setFocus(true)
    end if
end sub

' A screen finished by itself (e.g. a video ended): close it if it's on top.
sub onScreenDone(event as object)
    if m.screens.Count() > 1 and m.screens.Peek().isSameNode(event.getRoSGNode()) then popScreen()
end sub

sub resetTo(name as string)
    while m.screens.Count() > 0
        m.top.removeChild(m.screens.Pop())
    end while
    pushScreen(name)
end sub

' Screens request navigation by setting their `navigate` field to { screen, params }.
sub onNavigate(event as object)
    nav = event.getData()
    pushScreen(nav.screen, nav.params)
end sub

sub onConnected()
    applySettings(loadSettings())
    endLaunchDialog()
    m.connectedTimer.control = "start"
end sub

sub onConnectedTimer()
    resetTo("HomeScreen")
end sub

' User switched (PIN already checked) or removed: start over as the now-active user. After
' removing the active user none is active, so Who's watching appears (or sign-in if none left).
sub onProfilesChanged()
    settings = loadSettings()
    applySettings(settings)
    if hasSettings(settings)
        resetTo("HomeScreen")
    else if loadProfiles().profiles.Count() > 0
        resetTo("ProfilePickerScreen")
    else
        resetTo("LoginScreen")
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "back" then return false
    if m.screens.Count() > 1
        popScreen()
    else
        m.top.exitApp = true
    end if
    return true
end function

' ---- Memory ----

' Roku warns as the app nears its memory limit: screens with a lowMemory field free caches.
sub onMemoryWarning()
    logDebug("memory warning: " + m.top.memoryWarning.ToStr() + "% of the app's limit")
    for each screen in m.screens
        if screen.hasField("lowMemory") then screen.lowMemory = true
    end for
end sub
