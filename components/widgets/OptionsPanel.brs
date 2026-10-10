sub init()
    m.list = m.top.findNode("list")
    labels = ["All", "Photos", "Videos"]
    filters = mediaFilters()
    content = CreateObject("roSGNode", "ContentNode")
    current = 0
    for i = 0 to filters.Count() - 1
        title = labels[i]
        if filters[i] = m.global.mediaFilter
            title = title + "   (current)"
            current = i
        end if
        item = content.createChild("ContentNode")
        item.title = title
    end for
    m.list.content = content
    m.list.jumpToItem = current

    m.list.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.findNode("slide").control = "start"
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

sub onSelected()
    value = mediaFilters()[m.list.itemSelected]
    if value <> m.global.mediaFilter
        saveMediaFilter(value)
        m.global.mediaFilter = value
    end if
    m.top.closed = true
end sub

' The panel keeps focus until closed.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return true
    if key = "back" or key = "options" or key = "right"
        m.top.closed = true
    end if
    return true
end function
