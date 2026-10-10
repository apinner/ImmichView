' Circle colours, from the logo's purples; users take them in turn.
function tileColors() as object
    return ["0x8B57C3FF", "0x6E3997FF", "0xA274D4FF", "0x572C78FF", "0x7E4FB8FF"]
end function

sub init()
    m.ring = m.top.findNode("ring")
    m.circle = m.top.findNode("circle")
    m.initial = m.top.findNode("initial")
    m.lock = m.top.findNode("lock")
    m.name = m.top.findNode("name")
end sub

sub onContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    m.name.text = item.title
    if item.isAdd
        m.initial.text = "+"
        m.circle.blendColor = "0x3A3950FF"
    else
        m.initial.text = UCase(Left(item.title, 1))
        colors = tileColors()
        m.circle.blendColor = colors[item.colorIndex MOD colors.Count()]
    end if
    m.lock.visible = item.hasPin
end sub

sub onFocusChanged()
    focus = 0.0
    if m.top.gridHasFocus then focus = m.top.focusPercent
    m.ring.opacity = focus
    if focus > 0.5
        m.name.color = "0xFFFFFFFF"
    else
        m.name.color = "0xA0A8B0FF"
    end if
end sub
