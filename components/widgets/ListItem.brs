sub init()
    m.pill = m.top.findNode("pill")
    m.label = m.top.findNode("label")
end sub

sub onContentChanged()
    if m.top.itemContent <> invalid then m.label.text = m.top.itemContent.title
end sub

sub onSizeChanged()
    m.pill.width = m.top.width
    m.pill.height = m.top.height
    m.label.width = m.top.width - 64
    ' The label sits 3px low (see XML): vertical centring uses the font's line box, which
    ' includes room for descenders, so text centred that way looks high.
    m.label.height = m.top.height
end sub

sub updateStyle()
    isCurrent = m.top.focusPercent > 0.5
    m.pill.visible = isCurrent
    if isCurrent and m.top.listHasFocus
        m.pill.blendColor = "0xC6A1E7FF"
        m.label.color = "0x2D0F47FF"
        m.label.font = "font:MediumBoldSystemFont"
    else if isCurrent
        m.pill.blendColor = "0x4A2D66FF"
        m.label.color = "0xFFFFFFFF"
        m.label.font = "font:MediumSystemFont"
    else
        m.label.color = "0xE0E4E8FF"
        m.label.font = "font:MediumSystemFont"
    end if
end sub
