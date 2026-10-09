sub init()
    m.users = m.top.findNode("users")
    m.options = m.top.findNode("options")
    m.hint = m.top.findNode("hint")
    m.users.observeField("itemSelected", "onUserSelected")
    m.options.observeField("itemSelected", "onOptionSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    refreshUsers()
    refreshOptions()
end sub

sub onFocusChanged()
    if m.top.hasFocus() then focusList(m.users)
end sub

sub focusList(list as object)
    list.setFocus(true)
    if list.isSameNode(m.users)
        m.hint.text = "OK: switch to this user      * : remove user"
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
    setActiveProfile(profile.id)
    logDebug("switched user")
    m.top.profilesChanged = true
end sub

' ---- Slideshow ----

sub refreshOptions()
    content = CreateObject("roSGNode", "ContentNode")
    item = content.createChild("ContentNode")
    item.title = "Time per photo:   " + loadSlideshowSeconds().ToStr() + " seconds"
    m.options.content = content
end sub

' Cycles through the available intervals.
sub onOptionSelected()
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
        if index >= 0 and index < m.profiles.Count() then confirmRemove(m.profiles[index])
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
    focusList(m.users)
end sub
