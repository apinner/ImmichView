sub init()
    m.pill = m.top.findNode("pill")
    m.iconNode = m.top.findNode("iconNode")
    m.label = m.top.findNode("label")
    m.trailing = m.top.findNode("trailing")
    m.top.observeField("focusedChild", "updateStyle")
    layout()
end sub

sub layout()
    hasIcon = m.top.icon <> ""
    hasText = m.top.text <> ""
    hasTrailing = m.top.trailingIcon <> ""
    m.iconNode.uri = m.top.icon
    m.iconNode.visible = hasIcon
    m.label.text = m.top.text
    m.label.visible = hasText
    m.trailing.uri = m.top.trailingIcon
    m.trailing.visible = hasTrailing

    if not hasText and not hasTrailing
        width = 56  ' round icon button
    else
        x = 22
        if hasIcon
            m.iconNode.translation = [x, 14]
            x = x + 28 + 10
        end if
        if hasText
            m.label.translation = [x, 3]  ' +3px: line-box centring sits text high
            x = x + m.label.boundingRect().width
        end if
        if hasTrailing
            m.trailing.translation = [x + 10, 19]
            x = x + 10 + 18
        end if
        width = x + 22
    end if
    m.pill.width = width
    m.top.width = width
    updateStyle()
end sub

sub updateStyle()
    if m.top.hasFocus()
        m.pill.blendColor = "0xC6A1E7FF"
        foreground = "0x2D0F47FF"
    else
        m.pill.blendColor = "0x2E2D3AFF"
        foreground = "0xE0E4E8FF"
    end if
    m.label.color = foreground
    m.iconNode.blendColor = foreground
    m.trailing.blendColor = foreground
end sub
