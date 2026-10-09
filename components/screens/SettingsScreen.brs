sub init()
    m.users = m.top.findNode("users")
    m.users.observeField("itemSelected", "onUserSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    refreshUsers()
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.users.setFocus(true)
end sub

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

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "options" then return false
    index = m.users.itemFocused
    if index >= 0 and index < m.profiles.Count() then confirmRemove(m.profiles[index])
    return true
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
    m.users.setFocus(true)
end sub
