function tabWidth() as integer
    return 200
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

        pill = tabNode.createChild("Rectangle")
        pill.width = tabWidth()
        pill.height = 56
        pill.color = "0xADCBFAFF"

        label = tabNode.createChild("Label")
        label.width = tabWidth()
        label.height = 56
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.font = "font:MediumBoldSystemFont"
        label.text = title

        underline = tabNode.createChild("Rectangle")
        underline.translation = [50, 60]
        underline.width = tabWidth() - 100
        underline.height = 4
        underline.color = "0xADCBFAFF"

        m.tabNodes.Push({ pill: pill, label: label, underline: underline })
        x = x + tabWidth() + 16
    end for
    updateStyles()
end sub

' Focused: the selected tab is a filled pill. Unfocused: the selected tab is underlined.
sub updateStyles()
    focused = m.top.hasFocus()
    for i = 0 to m.tabNodes.Count() - 1
        tabNode = m.tabNodes[i]
        isSelected = (i = m.top.selected)
        tabNode.pill.visible = focused and isSelected
        tabNode.underline.visible = isSelected and not focused
        if focused and isSelected
            tabNode.label.color = "0x101418FF"
        else if isSelected
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
