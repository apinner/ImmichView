sub init()
    m.ring = m.top.findNode("ring")
    m.face = m.top.findNode("face")
    m.name = m.top.findNode("name")
    m.face.setHttpAgent(createAuthAgent())
end sub

sub onContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    m.face.uri = item.thumbUrl
    m.name.text = item.title
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
