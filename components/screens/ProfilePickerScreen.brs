function maxColumns() as integer
    return 5
end function

sub init()
    m.grid = m.top.findNode("grid")
    m.prompt = invalid
    data = loadProfiles()
    m.profiles = data.profiles

    content = CreateObject("roSGNode", "ContentNode")
    focusIndex = 0
    for i = 0 to m.profiles.Count() - 1
        profile = m.profiles[i]
        if profile.id = data.activeId then focusIndex = i
        item = content.createChild("ContentNode")
        item.update({ title: profileDisplayName(profile), colorIndex: i, hasPin: profileHasPin(profile), isAdd: false }, true)
    end for
    item = content.createChild("ContentNode")
    item.update({ title: "Add user", colorIndex: 0, hasPin: false, isAdd: true }, true)

    columns = content.getChildCount()
    if columns > maxColumns() then columns = maxColumns()
    m.grid.numColumns = columns
    width = columns * 232 + (columns - 1) * 56
    m.grid.translation = [Int((1920 - width) / 2), 380]
    m.grid.content = content
    m.grid.jumpToItem = focusIndex

    m.grid.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.grid.setFocus(true)
end sub

sub onSelected()
    index = m.grid.itemSelected
    if index >= m.profiles.Count()
        m.top.navigate = { screen: "LoginScreen" }
        return
    end if
    m.choosing = m.profiles[index]
    if not profileHasPin(m.choosing)
        choose()
        return
    end if
    m.prompt = CreateObject("roSGNode", "PinPrompt")
    m.top.appendChild(m.prompt)
    m.prompt.profile = m.choosing
    m.prompt.observeField("result", "onPinResult")
    m.prompt.start = true
end sub

sub onPinResult()
    result = m.prompt.result
    m.top.removeChild(m.prompt)
    m.prompt = invalid
    if result = "ok"
        choose()
    else
        m.grid.setFocus(true)
    end if
end sub

sub choose()
    setActiveProfile(m.choosing.id)
    logDebug("chose user")
    m.top.profileChosen = true
end sub
