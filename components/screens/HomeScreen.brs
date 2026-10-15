function timelineQuery() as string
    return "visibility=timeline&withPartners=true&withStacked=true&order=desc"
end function

sub init()
    m.tabs = m.top.findNode("tabs")
    m.timeline = m.top.findNode("timeline")
    m.albumsPane = m.top.findNode("albumsPane")
    m.albums = m.top.findNode("albums")
    m.albumStatus = m.top.findNode("albumStatus")
    m.placesPane = m.top.findNode("placesPane")
    m.places = m.top.findNode("places")
    m.placeStatus = m.top.findNode("placeStatus")
    m.placesLoaded = false
    m.peoplePane = m.top.findNode("peoplePane")
    m.searchPane = m.top.findNode("searchPane")
    m.status = m.top.findNode("status")
    m.failed = false
    m.albumsLoaded = false
    ' Tab index -> content pane, in TabBar order.
    m.panes = [m.timeline, m.albumsPane, m.peoplePane, m.placesPane, m.searchPane]

    m.tabs.observeField("selected", "onTabChanged")
    m.timeline.observeField("exitedTop", "focusTabs")
    m.timeline.observeField("loaded", "onTimelineLoaded")
    m.timeline.observeField("itemSelected", "onTimelineSelected")
    m.timeline.observeField("jumpRequested", "focusRail")
    m.timeline.observeField("months", "updateRail")
    m.timeline.observeField("monthIndex", "onMonthIndex")
    m.rail = m.top.findNode("rail")
    m.rail.observeField("chosen", "onRailChosen")
    m.rail.observeField("closed", "onRailClosed")
    m.albums.observeField("itemSelected", "onAlbumSelected")
    m.places.observeField("itemSelected", "onPlaceSelected")
    m.peoplePane.observeField("personSelected", "onPersonSelected")
    m.searchPane.observeField("itemSelected", "onSearchResultSelected")
    m.top.observeField("focusedChild", "onFocusChanged")

    m.tabs.tabs = ["Photos", "Albums", "People", "Places", "Search"]
    m.optionsHint = m.top.findNode("optionsHint")
    m.userPill = m.top.findNode("userPill")
    m.gearPill = m.top.findNode("gearPill")
    m.userPill.text = profileDisplayName(loadSettings())
    m.userPill.observeField("width", "layoutTopBar")
    layoutTopBar()
    m.overlay = invalid    ' open UserMenu or OptionsPanel
    m.overlayReturn = invalid
    loadUser()
    m.timeline.query = timelineQuery()
end sub

sub onFocusChanged()
    if m.top.hasFocus() then focusContent()
end sub

sub onTimelineLoaded()
    if m.timeline.loaded then m.top.ready = true
end sub

' ---- Tabs and focus ----

sub onTabChanged()
    selected = m.tabs.selected
    for i = 0 to m.panes.Count() - 1
        m.panes[i].visible = (i = selected) and not m.failed
    end for
    showRail()
    ' Left on the first photo of a row opens the Jump to panel on the Photos tab only.
    if selected = 0 then m.optionsHint.text = optionsHintText(true) else m.optionsHint.text = optionsHintText(false)
    if selected = 1 and not m.albumsLoaded then loadAlbums()
    if selected = 2 then m.peoplePane.load = true
    if selected = 3 and not m.placesLoaded then loadPlaces()
end sub

function optionsHintText(withJump as boolean) as string
    if withJump then return Chr(8592) + "  Jump to date        *  Options"
    return "*  Options"
end function

sub focusTabs()
    m.tabs.setFocus(true)
end sub

sub focusContent()
    selected = m.tabs.selected
    if m.failed
        m.tabs.setFocus(true)
    else if selected = 1
        if m.albums.content <> invalid then m.albums.setFocus(true) else m.tabs.setFocus(true)
    else if selected = 3
        if m.places.content <> invalid then m.places.setFocus(true) else m.tabs.setFocus(true)
    else
        m.panes[selected].setFocus(true)
    end if
end sub

' ---- Top bar: user pill (fast switching) and settings gear, right-aligned ----

sub layoutTopBar()
    gearX = 1840 - m.gearPill.width
    userX = gearX - 12 - m.userPill.width
    m.gearPill.translation = [gearX, 32]
    m.userPill.translation = [userX, 32]
    m.optionsHint.translation = [userX - 24 - 640, 32]
end sub

function topBarFocused() as boolean
    return m.userPill.isInFocusChain() or m.gearPill.isInFocusChain()
end function

function onTopBarKey(key as string) as boolean
    if key = "right" and m.userPill.hasFocus()
        m.gearPill.setFocus(true)
    else if key = "left" and m.gearPill.hasFocus()
        m.userPill.setFocus(true)
    else if key = "down" or key = "back"
        focusTabs()
    else if key = "OK" and m.userPill.hasFocus()
        openOverlay(CreateObject("roSGNode", "UserMenu"))
    else if key = "OK"
        m.top.navigate = { screen: "SettingsScreen" }
    else
        return false
    end if
    return true
end function

' ---- Timeline scrubber (left margin of the Photos tab) ----

sub updateRail()
    m.rail.months = m.timeline.months
    showRail()
end sub

' Only on the Photos tab, and only with more than one month to move between.
sub showRail()
    months = m.timeline.months
    m.rail.visible = (m.tabs.selected = 0 and not m.failed and months <> invalid and months.Count() > 1)
end sub

sub onMonthIndex()
    m.rail.current = m.timeline.monthIndex
end sub

' Left on the first photo of a row.
sub focusRail()
    if not m.rail.visible then return
    m.rail.cursor = m.timeline.monthIndex
    m.rail.setFocus(true)
end sub

sub onRailChosen()
    m.timeline.callFunc("jumpToMonth", m.rail.chosen)
    m.timeline.setFocus(true)
end sub

sub onRailClosed()
    m.timeline.setFocus(true)
end sub

' ---- Overlays: UserMenu (dropdown under the user pill) and OptionsPanel (* button) ----

sub openOverlay(overlay as object)
    ' Remember where focus was, to return there when the overlay closes.
    m.overlayReturn = m.tabs
    for each node in [m.userPill, m.gearPill, m.timeline, m.rail, m.albums, m.peoplePane, m.places, m.searchPane]
        if node.isInFocusChain() then m.overlayReturn = node
    end for
    if overlay.subtype() = "UserMenu"
        overlay.translation = [1840 - overlay.width, 100]
        overlay.observeField("profilesChanged", "onUserSwitched")
        overlay.observeField("manageUsers", "onManageUsers")
    end if
    overlay.observeField("closed", "closeOverlay")
    m.top.appendChild(overlay)
    m.overlay = overlay
    overlay.setFocus(true)
end sub

sub closeOverlay()
    if m.overlay = invalid then return
    m.top.removeChild(m.overlay)
    m.overlay = invalid
    m.overlayReturn.setFocus(true)
end sub

sub onUserSwitched()
    m.top.profilesChanged = true
end sub

sub onManageUsers()
    closeOverlay()
    m.top.navigate = { screen: "SettingsScreen" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "options"
        openOverlay(CreateObject("roSGNode", "OptionsPanel"))
        return true
    end if
    if key = "OK" and m.failed and not topBarFocused()
        m.top.navigate = { screen: "SettingsScreen" }
        return true
    end if
    if topBarFocused() then return onTopBarKey(key)
    if m.tabs.isInFocusChain()
        if key = "down" or key = "OK"
            focusContent()
            return true
        else if key = "up"
            m.userPill.setFocus(true)
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
        for each pane in m.panes
            pane.visible = false
        end for
        m.rail.visible = false
        m.status.text = describeApiError(resp) + Chr(10) + Chr(10) + "Press OK for Settings."
        focusTabs()
        m.top.ready = true
        return
    end if

    name = resp.data.name
    if name = invalid or name = "" then name = resp.data.email
    m.userPill.text = name
    profile = loadSettings()
    if profile.id <> "" and profile.name <> name then setProfileName(profile.id, name)
    avatar = avatarUrlFor(m.global.serverUrl, resp.data)
    if profile.id <> "" and profileAvatar(profile) <> avatar then setProfileAvatar(profile.id, avatar)
end sub

' ---- Photos tab ----

sub onTimelineSelected()
    m.top.navigate = assetNavigation(m.timeline, m.timeline.itemSelected)
end sub

' ---- People and Search tabs ----

sub onPersonSelected()
    person = m.peoplePane.personSelected
    m.top.navigate = {
        screen: "CollectionScreen"
        params: { source: { title: person.name, query: "personId=" + person.id + "&visibility=timeline&order=desc" } }
    }
end sub

sub onSearchResultSelected()
    m.top.navigate = assetNavigation(m.searchPane.results, m.searchPane.itemSelected)
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
        screen: "CollectionScreen"
        params: { source: { title: item.title, query: "albumId=" + item.albumId + "&order=" + item.order } }
    }
end sub

' ---- Places tab ----

' One photo per city from Immich (alphabetical), like the web app's Places page.
sub loadPlaces()
    m.placesLoaded = true
    m.placeStatus.text = "Loading places..."
    m.placesTask = startApiRequest(currentSettings(), "GET", "/api/search/cities", "onPlaces")
end sub

sub onPlaces(event as object)
    resp = event.getData()
    m.placesTask = invalid
    if not resp.ok
        m.placesLoaded = false
        m.placeStatus.text = describeApiError(resp)
        return
    end if
    content = CreateObject("roSGNode", "ContentNode")
    for each asset in resp.data
        exif = asset.exifInfo
        if exif <> invalid and exif.city <> invalid and exif.city <> ""
            state = exif.state
            if state = invalid then state = ""
            country = exif.country
            if country = invalid then country = ""
            item = content.createChild("ContentNode")
            item.update({
                title: exif.city
                subtitle: joinNonEmpty([state, country], ", ")
                thumbUrl: thumbnailUrl(asset.id, "thumbnail")
                city: exif.city
                state: state
                country: country
            }, true)
        end if
    end for
    if content.getChildCount() = 0
        m.placeStatus.text = "No places yet. Immich finds places from the location in your photos."
        return
    end if
    m.placeStatus.text = ""
    m.places.content = content
end sub

' Opens the photos taken in that city (matching region and country too, for towns that
' share a name).
sub onPlaceSelected()
    item = m.places.content.getChild(m.places.itemSelected)
    search = { city: item.city }
    if item.state <> "" then search.state = item.state
    if item.country <> "" then search.country = item.country
    m.top.navigate = {
        screen: "CollectionScreen"
        params: { source: { title: item.title, subtitle: item.subtitle, search: search } }
    }
end sub
