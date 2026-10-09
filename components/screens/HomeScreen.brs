sub init()
    m.rows = m.top.findNode("rows")
    m.status = m.top.findNode("status")
    m.failed = false

    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    loadAlbums()
end sub

' Focus goes to the rows once they have content; until then the screen keeps it for OK / Options.
sub onFocusChanged()
    if m.top.hasFocus() and m.rows.content <> invalid then m.rows.setFocus(true)
end sub

sub loadAlbums()
    m.failed = false
    m.status.text = "Loading albums..."
    m.task = startApiRequest(currentSettings(), "GET", "/api/albums", "onAlbums")
end sub

sub onAlbums(event as object)
    resp = event.getData()
    m.task = invalid
    if not resp.ok
        m.failed = true
        m.status.text = describeApiError(resp) + Chr(10) + Chr(10) + "Press OK to open Settings."
        return
    end if

    albums = resp.data
    if albums.Count() = 0
        m.status.text = "No albums yet. Create one in the Immich web app."
        return
    end if
    ' Newest photo first; empty albums have no endDate and go last.
    for each album in albums
        album.sortKey = ""
        if album.endDate <> invalid then album.sortKey = album.endDate
    end for
    albums.SortBy("sortKey", "r")

    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    row.title = "Albums"
    for each album in albums
        addAlbumItem(row, album)
    end for

    m.status.text = ""
    m.rows.content = root
    if m.top.isInFocusChain() then m.rows.setFocus(true)
end sub

sub addAlbumItem(row as object, album as object)
    order = "desc"
    if album.order <> invalid then order = album.order
    item = row.createChild("ContentNode")
    item.update({
        title: album.albumName
        albumId: album.id
        assetCount: album.assetCount
        order: order
        thumbUrl: thumbnailUrl(album.albumThumbnailAssetId, "thumbnail")
    }, true)
end sub

sub onItemSelected()
    selected = m.rows.rowItemSelected
    item = m.rows.content.getChild(selected[0]).getChild(selected[1])
    m.top.navigate = {
        screen: "AlbumGrid"
        params: { album: { albumId: item.albumId, title: item.title, assetCount: item.assetCount, order: item.order } }
    }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "options" or (key = "OK" and m.failed)
        m.top.navigate = { screen: "LoginScreen" }
        return true
    end if
    return false
end function
