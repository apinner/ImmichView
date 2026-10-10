sub init()
    m.title = m.top.findNode("title")
    m.count = m.top.findNode("count")
    m.timeline = m.top.findNode("timeline")
    m.panel = invalid

    m.timeline.observeField("itemSelected", "onItemSelected")
    m.timeline.observeField("totalCount", "updateCount")
    m.global.observeField("mediaFilter", "updateCount")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.timeline.setFocus(true)
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

' * opens the View options panel (photos/videos filter).
function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "options" then return false
    m.panel = CreateObject("roSGNode", "OptionsPanel")
    m.panel.observeField("closed", "onPanelClosed")
    m.top.appendChild(m.panel)
    m.panel.setFocus(true)
    return true
end function

sub onPanelClosed()
    m.top.removeChild(m.panel)
    m.panel = invalid
    m.timeline.setFocus(true)
end sub
