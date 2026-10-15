sub init()
    m.users = m.top.findNode("users")
    m.options = m.top.findNode("options")
    m.hint = m.top.findNode("hint")
    m.users.observeField("itemSelected", "onUserSelected")
    m.options.observeField("itemSelected", "onOptionSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.lastList = m.users
    refreshUsers()
    refreshOptions()
    version = CreateObject("roAppInfo").GetVersion()
    m.top.findNode("about").text = "ImmichView " + version + "   -   Unofficial app, not affiliated with or endorsed by Immich or FUTO."
    checkServer()
end sub

' Also runs when returning from the screensaver photo picker.
sub onFocusChanged()
    if not m.top.hasFocus() then return
    refreshOptions()
    focusList(m.lastList)
end sub

sub focusList(list as object)
    m.lastList = list
    list.setFocus(true)
    if list.isSameNode(m.users)
        m.hint.text = "OK: switch to this user      * : PIN or remove user"
    else
        m.hint.text = "OK: change"
    end if
end sub

' ---- Users ----

sub refreshUsers()
    data = loadProfiles()
    m.profiles = data.profiles
    m.activeId = data.activeId

    content = CreateObject("roSGNode", "ContentNode")
    for each profile in m.profiles
        title = profileDisplayName(profile) + "   -   " + serverHost(profile.serverUrl)
        if profileHasPin(profile) then title = title + "   (PIN)"
        if profile.id = m.activeId then title = title + "   (current)"
        item = content.createChild("ContentNode")
        item.title = title
    end for
    item = content.createChild("ContentNode")
    item.title = "+  Add user"

    focused = m.users.itemFocused
    m.users.content = content
    if focused > 0 and focused < content.getChildCount() then m.users.jumpToItem = focused
end sub

sub onUserSelected()
    index = m.users.itemSelected
    if index >= m.profiles.Count()
        m.top.navigate = { screen: "LoginScreen" }
        return
    end if
    profile = m.profiles[index]
    if profile.id = m.activeId then return
    m.target = profile
    if profileHasPin(profile)
        runPinPrompt("verify", "switch")
    else
        switchToTarget()
    end if
end sub

sub switchToTarget()
    setActiveProfile(m.target.id)
    logDebug("switched user")
    m.top.profilesChanged = true
end sub

' ---- PIN prompts: each runs one PinPrompt, then the named next step ----

sub runPinPrompt(mode as string, nextStep as string)
    m.nextStep = nextStep
    m.prompt = CreateObject("roSGNode", "PinPrompt")
    m.top.appendChild(m.prompt)
    m.prompt.profile = m.target
    m.prompt.mode = mode
    m.prompt.observeField("result", "onPinResult")
    m.prompt.start = true
end sub

sub onPinResult()
    result = m.prompt.result
    newPin = m.prompt.newPin
    m.top.removeChild(m.prompt)
    m.prompt = invalid
    if result <> "ok"
        focusList(m.users)
        return
    end if
    if m.nextStep = "switch"
        switchToTarget()
    else if m.nextStep = "choosePin"
        runPinPrompt("set", "savePin")   ' after verifying the current PIN
    else if m.nextStep = "savePin"
        setProfilePin(m.target.id, newPin)
        refreshUsers()
        focusList(m.users)
    else if m.nextStep = "clearPin"
        clearProfilePin(m.target.id)
        refreshUsers()
        focusList(m.users)
    else if m.nextStep = "remove"
        confirmRemove(m.target)
    end if
end sub

' ---- * on a user: PIN and remove options ----

sub showUserActions(profile as object)
    m.target = profile
    if profileHasPin(profile)
        m.actions = ["Change PIN", "Remove PIN", "Remove user", "Cancel"]
    else
        m.actions = ["Set PIN", "Remove user", "Cancel"]
    end if
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = profileDisplayName(profile)
    dlg.message = [serverHost(profile.serverUrl) + Chr(10) + "A PIN is asked for when switching to this user or opening the app as them. It keeps users private from each other on this Roku; it isn't a password."]
    dlg.buttons = m.actions
    dlg.observeField("buttonSelected", "onUserAction")
    dlg.observeField("wasClosed", "onActionsClosed")
    m.actionsDialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub onUserAction()
    action = m.actions[m.actionsDialog.buttonSelected]
    hasPin = profileHasPin(m.target)
    if action = "Set PIN"
        runPinPrompt("set", "savePin")
    else if action = "Change PIN"
        runPinPrompt("verify", "choosePin")
    else if action = "Remove PIN"
        runPinPrompt("verify", "clearPin")
    else if action = "Remove user" and hasPin
        runPinPrompt("verify", "remove")
    else if action = "Remove user"
        confirmRemove(m.target)
    else
        m.actionsDialog.close = true
    end if
end sub

' Back or Cancel on the actions dialog; ignored when it was replaced by a PIN or remove dialog.
sub onActionsClosed(event as object)
    if m.prompt <> invalid or m.dialog <> invalid then return
    if not event.getRoSGNode().isSameNode(m.actionsDialog) then return
    focusList(m.users)
end sub

' ---- Slideshow and screensaver ----

sub refreshOptions()
    screensaver = loadScreensaverSettings()
    titles = [
        "Time per photo:   " + loadSlideshowSeconds().ToStr() + " seconds"
        "Show people's names on photos:   " + onOff(loadShowPeopleNames())
        "Photo background:   " + photoBackgroundLabel(loadPhotoBackground())
        "Screensaver photos:   " + screensaverSourceLabel(screensaver)
        "Screensaver shows date and place:   " + onOff(screensaver.showCaption)
        "Screensaver shows the time:   " + onOff(screensaver.showClock)
    ]
    content = CreateObject("roSGNode", "ContentNode")
    for each title in titles
        item = content.createChild("ContentNode")
        item.title = title
    end for
    focused = m.options.itemFocused
    m.options.content = content
    if focused > 0 then m.options.jumpToItem = focused
end sub

sub onOptionSelected()
    index = m.options.itemSelected
    if index = 0
        cycleSlideshowInterval()
    else if index = 1
        saveShowPeopleNames(not loadShowPeopleNames())
    else if index = 2
        cyclePhotoBackground()
    else if index = 3
        m.top.navigate = { screen: "ScreensaverSourceScreen" }
    else if index = 4
        saveScreensaverCaption(not loadScreensaverSettings().showCaption)
    else if index = 5
        saveScreensaverClock(not loadScreensaverSettings().showClock)
    end if
    refreshOptions()
end sub

function onOff(value as boolean) as string
    if value then return "On"
    return "Off"
end function

sub cyclePhotoBackground()
    options = photoBackgrounds()
    current = loadPhotoBackground()
    nextValue = options[0]
    for i = 0 to options.Count() - 2
        if options[i] = current then nextValue = options[i + 1]
    end for
    savePhotoBackground(nextValue)
end sub

sub cycleSlideshowInterval()
    intervals = slideshowIntervals()
    current = loadSlideshowSeconds()
    nextValue = intervals[0]
    for i = 0 to intervals.Count() - 2
        if intervals[i] = current then nextValue = intervals[i + 1]
    end for
    saveSlideshowSeconds(nextValue)
    refreshOptions()
end sub

' ---- Keys ----

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "down" and m.users.hasFocus()
        focusList(m.options)
        return true
    else if key = "up" and m.options.hasFocus()
        focusList(m.users)
        return true
    else if key = "options" and m.users.hasFocus()
        index = m.users.itemFocused
        if index >= 0 and index < m.profiles.Count() then showUserActions(m.profiles[index])
        return true
    end if
    return false
end function

' ---- Remove user ----

sub confirmRemove(profile as object)
    m.removing = profile
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Remove user?"
    dlg.message = ["Remove " + profileDisplayName(profile) + " (" + serverHost(profile.serverUrl) + ") from this Roku?"]
    dlg.buttons = ["Remove", "Cancel"]
    dlg.observeField("buttonSelected", "onRemoveButton")
    dlg.observeField("wasClosed", "onDialogClosed")
    m.dialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub onRemoveButton()
    if m.dialog.buttonSelected = 0
        wasActive = (m.removing.id = m.activeId)
        removeProfile(m.removing.id)
        if wasActive
            m.top.profilesChanged = true
        else
            refreshUsers()
        end if
    end if
    m.dialog.close = true
end sub

sub onDialogClosed()
    m.dialog = invalid
    if m.prompt = invalid then focusList(m.users)
end sub

' ---- Server status (top right): ping, then version ----

sub checkServer()
    showStatus("Checking server...", "0x80888FFF")
    m.statusTask = startApiRequest(currentSettings(), "GET", "/api/server/ping", "onPing")
end sub

sub onPing(event as object)
    resp = event.getData()
    m.statusTask = invalid
    if not resp.ok
        showStatus("Offline   " + Chr(183) + "   " + describeApiError(resp), "0xE5484DFF")
        return
    end if
    m.statusTask = startApiRequest(currentSettings(), "GET", "/api/server/version", "onVersion")
end sub

sub onVersion(event as object)
    resp = event.getData()
    m.statusTask = invalid
    parts = ["Online"]
    if resp.ok and resp.data.major <> invalid
        parts.Push("Immich v" + resp.data.major.ToStr() + "." + resp.data.minor.ToStr() + "." + resp.data.patch.ToStr())
    end if
    parts.Push(serverHost(m.global.serverUrl))
    showStatus(parts.Join("   " + Chr(183) + "   "), "0x4CC38AFF")
end sub

' Right-aligned to the screen margin (the label sizes to its text), with the dot before it.
sub showStatus(text as string, color as string)
    label = m.top.findNode("statusText")
    label.text = text
    width = label.boundingRect().width
    label.translation = [1760 - width, 88]
    dot = m.top.findNode("statusDot")
    dot.blendColor = color
    dot.translation = [1760 - width - 28, 100]
end sub
