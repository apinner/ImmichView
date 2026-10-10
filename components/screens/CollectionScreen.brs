sub init()
    m.title = m.top.findNode("title")
    m.count = m.top.findNode("count")
    m.timeline = m.top.findNode("timeline")
    m.filter = m.top.findNode("filter")
    m.filter.translation = [1840 - m.filter.totalWidth, 56]

    m.timeline.observeField("itemSelected", "onItemSelected")
    m.timeline.observeField("totalCount", "updateCount")
    m.timeline.observeField("exitedTop", "focusFilter")
    m.global.observeField("mediaFilter", "updateCount")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.timeline.setFocus(true)
end sub

sub focusFilter()
    m.filter.setFocus(true)
end sub

sub onSourceSet()
    m.title.text = m.top.source.title
    m.timeline.query = m.top.source.query
end sub

' "1281 items", or which filter is on (bucket counts include both photos and videos).
sub updateCount()
    if m.global.mediaFilter = "photos"
        m.count.text = "Photos only"
    else if m.global.mediaFilter = "videos"
        m.count.text = "Videos only"
    else if m.timeline.totalCount >= 0
        m.count.text = formatItemCount(m.timeline.totalCount)
    else
        m.count.text = ""
    end if
end sub

sub onItemSelected()
    m.top.navigate = assetNavigation(m.timeline, m.timeline.itemSelected)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.filter.isInFocusChain() and (key = "down" or key = "OK")
        m.timeline.setFocus(true)
        return true
    end if
    return false
end function
