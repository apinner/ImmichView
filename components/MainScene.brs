sub init()
    m.top.backgroundColor = "0x101418FF"
    m.screens = []

    login = pushScreen("LoginScreen")
    if hasSettings(loadSettings()) then login.autoConnect = true
end sub

function pushScreen(name as string) as object
    screen = CreateObject("roSGNode", name)
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

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "back" then return false
    if m.screens.Count() > 1
        popScreen()
    else
        m.top.exitApp = true
    end if
    return true
end function
