' Horizontal space around each tab's text inside its pill.
function tabPadding() as integer
    return 36
end function

sub init()
    m.tabNodes = []
    m.top.observeField("focusedChild", "updateStyles")
end sub

sub onTabsChanged()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    m.tabNodes = []
    x = 0
    for each title in m.top.tabs
        tabNode = m.top.createChild("Group")
        tabNode.translation = [x, 0]

        label = CreateObject("roSGNode", "Label")
        label.font = "font:MediumBoldSystemFont"
        label.text = title
        width = label.boundingRect().width + tabPadding() * 2

        pill = tabNode.createChild("Poster")
        pill.uri = "pkg:/images/pill.9.png"
        pill.width = width
        pill.height = 56

        label.width = width
        label.height = 56
        label.horizAlign = "center"
        label.vertAlign = "center"
        tabNode.appendChild(label)

        m.tabNodes.Push({ pill: pill, label: label })
        x = x + width + 12
    end for
    updateStyles()
end sub

' Selected tab: a light pill while the tabs have focus, a dark pill otherwise.
sub updateStyles()
    focused = m.top.hasFocus()
    for i = 0 to m.tabNodes.Count() - 1
        tabNode = m.tabNodes[i]
        isSelected = (i = m.top.selected)
        tabNode.pill.visible = isSelected
        if isSelected and focused
            tabNode.pill.blendColor = "0xADCBFAFF"
            tabNode.label.color = "0x0B0E11FF"
        else if isSelected
            tabNode.pill.blendColor = "0x3A3950FF"
            tabNode.label.color = "0xFFFFFFFF"
        else
            tabNode.label.color = "0x80888FFF"
        end if
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "left" and m.top.selected > 0
        m.top.selected = m.top.selected - 1
        return true
    else if key = "right" and m.top.selected < m.tabNodes.Count() - 1
        m.top.selected = m.top.selected + 1
        return true
    end if
    return false
end function
