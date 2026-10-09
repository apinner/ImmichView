sub init()
    m.thumb = m.top.findNode("thumb")
    m.badge = m.top.findNode("badge")
    m.duration = m.top.findNode("duration")
    m.thumb.setHttpAgent(createAuthAgent())
end sub

sub onContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    m.thumb.uri = item.thumbUrl
    m.badge.visible = item.isVideo
    if item.isVideo then m.duration.text = formatDuration(item.durationMs)
end sub
