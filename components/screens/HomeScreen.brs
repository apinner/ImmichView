function timelineQuery() as string
    return "visibility=timeline&withPartners=true&withStacked=true&order=desc"
end function

sub init()
    m.tabs = m.top.findNode("tabs")
    m.timeline = m.top.findNode("timeline")
    m.albumsPane = m.top.findNode("albumsPane")
    m.albums = m.top.findNode("albums")
    m.albumStatus = m.top.findNode("albumStatus")
    m.userName = m.top.findNode("userName")
    m.status = m.top.findNode("status")
    m.failed = false
    m.albumsLoaded = false

    m.tabs.observeField("selected", "onTabChanged")
    m.timeline.observeField("exitedTop", "focusTabs")
    m.timeline.observeField("itemSelected", "onTimelineSelected")
    m.albums.observeField("itemSelected", "onAlbumSelected")
    m.top.observeField("focusedChild", "onFocusChanged")

    m.tabs.tabs = ["Photos", "Albums"]
    loadUser()
    m.timeline.query = timelineQuery()
end sub

sub onFocusChanged()
    if m.top.hasFocus() then focusContent()
end sub

' ---- Tabs and focus ----

sub onTabChanged()
    showAlbums = (m.tabs.selected = 1)
    m.timeline.visible = not showAlbums
    m.albumsPane.visible = showAlbums
    if showAlbums and not m.albumsLoaded then loadAlbums()
end sub

sub focusTabs()
    m.tabs.setFocus(true)
end sub

sub focusContent()
    if m.failed
        m.tabs.setFocus(true)
    else if m.tabs.selected = 0
        m.timeline.setFocus(true)
    else if m.albums.content <> invalid
        m.albums.setFocus(true)
    else
        m.tabs.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "options" or (key = "OK" and m.failed)
        m.top.navigate = { screen: "SettingsScreen" }
        return true
    end if
    if m.tabs.isInFocusChain()
        if key = "down" or key = "OK"
            focusContent()
            return true
        end if
    else if key = "up" or key = "back"
        ' Back from content goes to the tabs first; Back on the tabs exits.
        focusTabs()
        return true
    end if
    return false
end function

' ---- Current user ----

sub loadUser()
    m.userTask = startApiRequest(currentSettings(), "GET", "/api/users/me", "onUser")
end sub

sub onUser(event as object)
    resp = event.getData()
    m.userTask = invalid
    if not resp.ok
        m.failed = true
        m.timeline.visible = false
        m.albumsPane.visible = false
        m.status.text = describeApiError(resp) + Chr(10) + Chr(10) + "Press OK for Settings."
        focusTabs()
        return
    end if

    name = resp.data.name
    if name = invalid or name = "" then name = resp.data.email
    m.userName.text = name + "     * Users and settings"
    profile = loadSettings()
    if profile.id <> "" and profile.name <> name then setProfileName(profile.id, name)
end sub

' ---- Photos tab ----

sub onTimelineSelected()
    m.top.navigate = {
        screen: "PhotoViewer"
        params: { open: { timeline: m.timeline, index: m.timeline.itemSelected.index } }
    }
end sub

' ---- Albums tab ----

sub loadAlbums()
    m.albumsLoaded = true
    m.albumStatus.text = "Loading albums..."
    m.albumsTask = startApiRequest(currentSettings(), "GET", "/api/albums", "onAlbums")
end sub

sub onAlbums(event as object)
    resp = event.getData()
    m.albumsTask = invalid
    if not resp.ok
        m.albumsLoaded = false
        m.albumStatus.text = describeApiError(resp)
        return
    end if

    albums = resp.data
    if albums.Count() = 0
        m.albumStatus.text = "No albums yet. Create one in the Immich web app."
        return
    end if
    ' Newest photo first; empty albums have no endDate and go last.
    for each album in albums
        album.sortKey = ""
        if album.endDate <> invalid then album.sortKey = album.endDate
    end for
    albums.SortBy("sortKey", "r")

    content = CreateObject("roSGNode", "ContentNode")
    for each album in albums
        addAlbumItem(content, album)
    end for
    m.albumStatus.text = ""
    m.albums.content = content
end sub

sub addAlbumItem(content as object, album as object)
    order = "desc"
    if album.order <> invalid then order = album.order
    item = content.createChild("ContentNode")
    item.update({
        title: album.albumName
        albumId: album.id
        assetCount: album.assetCount
        order: order
        thumbUrl: thumbnailUrl(album.albumThumbnailAssetId, "thumbnail")
    }, true)
end sub

sub onAlbumSelected()
    item = m.albums.content.getChild(m.albums.itemSelected)
    m.top.navigate = {
        screen: "AlbumGrid"
        params: { album: { albumId: item.albumId, title: item.title, assetCount: item.assetCount, order: item.order } }
    }
end sub
