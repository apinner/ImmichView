sub init()
    m.pills = m.top.findNode("pills")
    m.pills.tabs = ["All", "Photos", "Videos"]
    showGlobalFilter()
    m.pills.observeField("selected", "onSelected")
    m.global.observeField("mediaFilter", "showGlobalFilter")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.pills.setFocus(true)
end sub

sub showGlobalFilter()
    filters = mediaFilters()
    for i = 0 to filters.Count() - 1
        if filters[i] = m.global.mediaFilter and m.pills.selected <> i then m.pills.selected = i
    end for
end sub

sub onSelected()
    value = mediaFilters()[m.pills.selected]
    if value = m.global.mediaFilter then return
    saveMediaFilter(value)
    m.global.mediaFilter = value
end sub
