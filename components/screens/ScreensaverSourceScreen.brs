sub init()
    m.sources = m.top.findNode("sources")
    m.status = m.top.findNode("status")
    m.albums = []
    m.sources.observeField("itemSelected", "onSourceSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    refreshList()
    m.status.text = "Loading albums..."
    m.task = startApiRequest(currentSettings(), "GET", "/api/albums", "onAlbums")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.sources.setFocus(true)
end sub

sub onAlbums(event as object)
    resp = event.getData()
    m.task = invalid
    if not resp.ok
        m.status.text = describeApiError(resp)
        return
    end if
    m.albums = []
    for each album in resp.data
        if album.assetCount > 0 then m.albums.Push({ id: album.id, name: album.albumName })
    end for
    m.albums.SortBy("name", "i")
    m.status.text = ""
    refreshList()
end sub

' Random and memories first, then one row per album; the current choice is marked.
sub refreshList()
    current = loadScreensaverSettings()
    content = CreateObject("roSGNode", "ContentNode")
    addSource(content, "Random photos from your library", current.source = "random")
    addSource(content, "Memories (on this day)", current.source = "memories")
    for each album in m.albums
        addSource(content, "Album: " + album.name, current.source = "album" and current.albumId = album.id)
    end for
    focused = m.sources.itemFocused
    m.sources.content = content
    if focused > 0 and focused < content.getChildCount() then m.sources.jumpToItem = focused
end sub

sub addSource(content as object, title as string, isCurrent as boolean)
    item = content.createChild("ContentNode")
    if isCurrent then title = title + "   (current)"
    item.title = title
end sub

sub onSourceSelected()
    index = m.sources.itemSelected
    if index = 0
        saveScreensaverSource("random", "", "")
    else if index = 1
        saveScreensaverSource("memories", "", "")
    else
        album = m.albums[index - 2]
        saveScreensaverSource("album", album.id, album.name)
    end if
    m.top.done = true
end sub
