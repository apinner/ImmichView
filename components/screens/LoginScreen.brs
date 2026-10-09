sub init()
    m.menu = m.top.findNode("menu")
    m.status = m.top.findNode("status")
    m.busy = false

    settings = loadSettings()
    m.serverUrl = settings.serverUrl
    m.apiKey = settings.apiKey

    m.menu.observeField("itemSelected", "onMenuSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    refreshMenu()
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.menu.setFocus(true)
end sub

' ---- Menu ----

sub refreshMenu()
    content = CreateObject("roSGNode", "ContentNode")
    addMenuItem(content, "Server URL:   " + displayValue(m.serverUrl, false))
    addMenuItem(content, "API key:   " + displayValue(m.apiKey, true))
    addMenuItem(content, "Connect")
    focused = m.menu.itemFocused
    m.menu.content = content
    if focused > 0 then m.menu.jumpToItem = focused
end sub

sub addMenuItem(content as object, title as string)
    item = content.createChild("ContentNode")
    item.title = title
end sub

function displayValue(value as string, secret as boolean) as string
    if value = "" then return "(not set)"
    if not secret then return value
    if Len(value) <= 4 then return "****"
    return "****" + Right(value, 4)
end function

sub onMenuSelected()
    if m.busy then return
    index = m.menu.itemSelected
    if index = 0
        showKeyboard("Server URL", m.serverUrl, "serverUrl", "e.g. http://192.168.1.20:2283 or https://photos.example.com")
    else if index = 1
        showKeyboard("API key", m.apiKey, "apiKey", "Paste or type the key from Account Settings > API Keys")
    else if index = 2
        startConnect()
    end if
end sub

' ---- Keyboard dialog ----

sub showKeyboard(title as string, value as string, field as string, message as string)
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = title
    dlg.message = [message]
    dlg.text = value
    dlg.buttons = ["OK", "Cancel"]
    dlg.observeField("buttonSelected", "onKeyboardButton")
    dlg.observeField("wasClosed", "onKeyboardClosed")
    m.editingField = field
    m.dialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub onKeyboardButton()
    if m.dialog.buttonSelected = 0
        value = m.dialog.text.Trim()
        if m.editingField = "serverUrl"
            m.serverUrl = normalizeServerUrl(value)
        else
            m.apiKey = value
        end if
        setStatus("", "info")
        refreshMenu()
    end if
    m.dialog.close = true
end sub

sub onKeyboardClosed()
    m.dialog = invalid
    m.menu.setFocus(true)
end sub

' ---- Connection check: ping -> version -> users/me ----

sub startConnect()
    if m.serverUrl = "" or m.apiKey = ""
        setStatus("Enter the server URL and API key first.", "error")
        return
    end if
    m.busy = true
    m.check = { serverUrl: m.serverUrl, apiKey: m.apiKey, version: "" }
    setStatus("Contacting " + m.serverUrl + " ...", "info")
    m.task = startApiRequest(m.check, "GET", "/api/server/ping", "onPing")
end sub

sub onPing(event as object)
    resp = event.getData()
    if not resp.ok
        failConnect(describeApiError(resp))
        return
    end if
    if type(resp.data) <> "roAssociativeArray" or resp.data.res = invalid or resp.data.res <> "pong"
        failConnect("That URL answered, but it doesn't look like an Immich server.")
        return
    end if
    m.task = startApiRequest(m.check, "GET", "/api/server/version", "onVersion")
end sub

sub onVersion(event as object)
    resp = event.getData()
    ' Not fatal: the version only adds detail to the status line.
    if resp.ok and type(resp.data) = "roAssociativeArray" and resp.data.major <> invalid
        v = resp.data
        m.check.version = v.major.ToStr() + "." + v.minor.ToStr() + "." + v.patch.ToStr()
        logDebug("server version " + m.check.version)
    end if
    m.task = startApiRequest(m.check, "GET", "/api/users/me", "onMe")
end sub

sub onMe(event as object)
    resp = event.getData()
    if not resp.ok
        failConnect(describeApiError(resp))
        return
    end if

    user = resp.data
    name = user.name
    if name = invalid or name = "" then name = user.email
    saveSettings(m.check.serverUrl, m.check.apiKey)

    text = "Connected as " + name
    if m.check.version <> "" then text = text + "  (Immich v" + m.check.version + ")"
    setStatus(text, "ok")
    m.busy = false
    m.task = invalid
    m.top.connectedUser = { name: name, email: user.email, serverVersion: m.check.version }
end sub

sub failConnect(message as string)
    setStatus(message, "error")
    m.busy = false
    m.task = invalid
end sub

sub setStatus(text as string, level as string)
    colors = { info: "0xE0E4E8FF", ok: "0x6FD08CFF", error: "0xFF7A7AFF" }
    m.status.color = colors[level]
    m.status.text = text
end sub
