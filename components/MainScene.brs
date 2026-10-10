sub init()
    m.top.backgroundUri = ""  ' the theme's default background image would hide backgroundColor
    m.top.backgroundColor = "0x24232FFF"
    m.screens = []
    m.global.addFields({ serverUrl: "", apiKey: "" })

    ' Short pause after "Connected as ..." so the confirmation is readable.
    m.connectedTimer = CreateObject("roSGNode", "Timer")
    m.connectedTimer.duration = 1.5
    m.connectedTimer.observeField("fire", "onConnectedTimer")
    m.top.appendChild(m.connectedTimer)

    settings = loadSettings()
    applySettings(settings)
    if hasSettings(settings)
        resetTo("HomeScreen")
    else
        resetTo("LoginScreen")
    end if
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
    if name = "SettingsScreen" then screen.observeField("profilesChanged", "onProfilesChanged")
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
    m.connectedTimer.control = "start"
end sub

sub onConnectedTimer()
    resetTo("HomeScreen")
end sub

' User switched or removed in Settings: start over as the now-active user.
sub onProfilesChanged()
    settings = loadSettings()
    applySettings(settings)
    if hasSettings(settings)
        resetTo("HomeScreen")
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
