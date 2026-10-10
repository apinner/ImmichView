sub init()
    m.list = m.top.findNode("list")
    data = loadProfiles()
    m.profiles = data.profiles
    m.activeId = data.activeId

    content = CreateObject("roSGNode", "ContentNode")
    focusIndex = 0
    for i = 0 to m.profiles.Count() - 1
        profile = m.profiles[i]
        title = profileDisplayName(profile)
        if profile.id = m.activeId
            title = title + "   (current)"
            focusIndex = i
        else if profileHasPin(profile)
            title = title + "   (PIN)"
        end if
        item = content.createChild("ContentNode")
        item.title = title
    end for
    item = content.createChild("ContentNode")
    item.title = "Add or manage users"

    rows = content.getChildCount()
    visible = rows
    if visible > 7 then visible = 7
    m.list.numRows = visible
    m.list.content = content
    m.list.jumpToItem = focusIndex
    m.top.findNode("card").height = 32 + visible * 70 - 6

    m.list.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

sub onSelected()
    index = m.list.itemSelected
    if index >= m.profiles.Count()
        m.top.manageUsers = true
        return
    end if
    m.switchTo = m.profiles[index]
    if m.switchTo.id = m.activeId
        m.top.closed = true
        return
    end if
    if not profileHasPin(m.switchTo)
        switchUser()
        return
    end if
    m.prompt = CreateObject("roSGNode", "PinPrompt")
    m.top.appendChild(m.prompt)
    m.prompt.profile = m.switchTo
    m.prompt.observeField("result", "onPinResult")
    m.prompt.start = true
end sub

sub onPinResult()
    result = m.prompt.result
    m.top.removeChild(m.prompt)
    m.prompt = invalid
    if result = "ok"
        switchUser()
    else
        m.list.setFocus(true)
    end if
end sub

sub switchUser()
    setActiveProfile(m.switchTo.id)
    m.top.profilesChanged = true
end sub

' The menu keeps focus until closed: Back, Up past the top or * closes it.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return true
    if key = "back" or key = "options" or key = "up"
        m.top.closed = true
    end if
    return true
end function
