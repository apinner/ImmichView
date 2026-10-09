sub init()
    m.title = m.top.findNode("title")
    m.count = m.top.findNode("count")
    m.timeline = m.top.findNode("timeline")
    m.timeline.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.timeline.setFocus(true)
end sub

sub onAlbumSet()
    album = m.top.album
    m.title.text = album.title
    m.count.text = formatItemCount(album.assetCount)
    m.timeline.query = "albumId=" + album.albumId + "&order=" + album.order
end sub

sub onItemSelected()
    m.top.navigate = {
        screen: "PhotoViewer"
        params: { open: { timeline: m.timeline, index: m.timeline.itemSelected.index } }
    }
end sub
