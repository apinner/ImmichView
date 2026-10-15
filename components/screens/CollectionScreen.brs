sub init()
    m.title = m.top.findNode("title")
    m.count = m.top.findNode("count")
    m.timeline = m.top.findNode("timeline")
    m.panel = invalid

    m.timeline.observeField("itemSelected", "onItemSelected")
    m.timeline.observeField("totalCount", "updateCount")
    m.timeline.observeField("jumpRequested", "openMonthPanel")
    m.timeline.observeField("months", "updateHint")
    m.global.observeField("mediaFilter", "updateCount")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.timeline.setFocus(true)
end sub

sub onSourceSet()
    m.title.text = m.top.source.title
    if m.top.source.search <> invalid
        m.timeline.metadataSearch = m.top.source.search  ' a place
    else
        m.timeline.query = m.top.source.query
    end if
    updateCount()
end sub

' "1281 items", or which filter is on (bucket counts include both photos and videos).
sub updateCount()
    if m.global.mediaFilter = "photos"
        m.count.text = "Photos only"
    else if m.global.mediaFilter = "videos"
        m.count.text = "Videos only"
    else if m.timeline.totalCount >= 0
        m.count.text = formatItemCount(m.timeline.totalCount)
    else if m.top.source <> invalid and m.top.source.subtitle <> invalid
        m.count.text = m.top.source.subtitle  ' a place: its region and country
    else
        m.count.text = ""
    end if
end sub

sub onItemSelected()
    m.top.navigate = assetNavigation(m.timeline, m.timeline.itemSelected)
end sub

' "Jump to date" only when there's more than one month to jump between.
sub updateHint()
    hint = "*  Options"
    if m.timeline.months.Count() > 1 then hint = Chr(8592) + "  Jump to date        " + hint
    m.top.findNode("hint").text = hint
end sub

' * opens the View options panel (photos/videos filter).
function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "options" then return false
    openPanel(CreateObject("roSGNode", "OptionsPanel"))
    return true
end function

' Left on the first photo of a row: the Jump to panel (months).
sub openMonthPanel()
    panel = CreateObject("roSGNode", "MonthPanel")
    panel.months = m.timeline.months
    panel.current = m.timeline.monthIndex
    panel.observeField("chosen", "onMonthChosen")
    openPanel(panel)
end sub

sub onMonthChosen()
    m.timeline.callFunc("jumpToMonth", m.panel.chosen)
end sub

sub openPanel(panel as object)
    m.panel = panel
    m.panel.observeField("closed", "onPanelClosed")
    m.top.appendChild(m.panel)
    m.panel.setFocus(true)
end sub

sub onPanelClosed()
    m.top.removeChild(m.panel)
    m.panel = invalid
    m.timeline.setFocus(true)
end sub
