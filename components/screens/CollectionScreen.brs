sub init()
    m.title = m.top.findNode("title")
    m.count = m.top.findNode("count")
    m.timeline = m.top.findNode("timeline")
    m.timeline.observeField("itemSelected", "onItemSelected")
    m.timeline.observeField("totalCount", "onTotalCount")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.timeline.setFocus(true)
end sub

sub onSourceSet()
    m.title.text = m.top.source.title
    m.timeline.query = m.top.source.query
end sub

sub onTotalCount()
    if m.timeline.totalCount >= 0 then m.count.text = formatItemCount(m.timeline.totalCount)
end sub

sub onItemSelected()
    m.top.navigate = assetNavigation(m.timeline, m.timeline.itemSelected)
end sub
