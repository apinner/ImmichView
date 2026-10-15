' Fade lengths in seconds.
function manualFade() as float
    return 0.35
end function

function slideshowFade() as float
    return 1.0
end function

sub init()
    m.stage = m.top.findNode("stage")
    m.message = m.top.findNode("message")
    m.videoNote = m.top.findNode("videoNote")
    m.videoText = m.top.findNode("videoText")
    m.info = m.top.findNode("info")
    m.toast = m.top.findNode("toast")
    m.toastText = m.top.findNode("toastText")
    m.toastAnim = m.top.findNode("toastAnim")
    m.fade = m.top.findNode("fade")
    m.fadeIn = m.top.findNode("fadeIn")
    m.fadeOut = m.top.findNode("fadeOut")
    m.slideTimer = m.top.findNode("slideTimer")
    m.slideTimer.observeField("fire", "onSlideTimer")
    m.names = m.top.findNode("names")
    m.namesText = m.top.findNode("namesText")
    m.namesShadow = m.top.findNode("namesShadow")
    m.ring = m.top.findNode("ring")
    m.showPeople = loadShowPeopleNames()

    agent = createAuthAgent()
    m.posters = []
    m.posterIndex = []      ' asset index each poster holds, -1 if none
    m.readyUri = {}         ' poster id -> uri that finished loading
    m.kenBurns = {}         ' poster id -> its Ken Burns animation
    m.backs = {}            ' poster id -> its background poster (blur / ambient glow)
    m.backsGroup = m.top.findNode("backs")
    for each id in ["p0", "p1", "p2"]
        poster = m.top.findNode(id)
        poster.setHttpAgent(agent)
        poster.observeField("loadStatus", "onPosterStatus")
        poster.observeField("opacity", "onPosterOpacity")
        back = m.top.findNode("b" + Right(id, 1))
        back.setHttpAgent(agent)
        m.backs[id] = back
        m.posters.Push(poster)
        m.posterIndex.Push(-1)
        m.readyUri[id] = ""
        m.kenBurns[id] = createKenBurns(poster)
    end for

    applyPhotoBackground(loadPhotoBackground())

    m.index = -1
    m.target = invalid      ' poster for m.index
    m.shown = invalid       ' poster currently faded in
    m.fadeSeconds = 0.0
    m.slideshow = false
    m.pendingNext = ""      ' "", "manual" or "slideshow" while waiting for more assets
    m.infoCache = {}
end sub

sub onOpen()
    m.timeline = m.top.open.timeline
    m.timeline.observeFieldScoped("assetCount", "onAssetCountChanged")
    showIndex(m.top.open.index, 0.0)
end sub

' ---- Navigation ----

function assetAt(index as integer) as dynamic
    return m.timeline.callFunc("getAsset", index)
end function

sub showIndex(index as integer, fadeSeconds as float)
    m.index = index
    m.fadeSeconds = fadeSeconds
    assignPosters()
    m.target = m.posters[posterSlotFor(index)]

    asset = assetAt(index)
    m.videoNote.visible = asset.isVideo
    if asset.isVideo then m.videoText.text = "Video  " + formatDuration(asset.durationMs) + "  -  press OK to play"

    logDebug("show " + index.ToStr() + " preloaded=" + isReady(m.target).ToStr() + " slideshow=" + m.slideshow.ToStr())
    if isReady(m.target)
        m.message.text = ""
        presentTarget()
    else
        m.message.text = "Loading..."
    end if
    if m.info.visible or m.showPeople then loadDetails()

    ' Ask for the next month early so moving on doesn't stall.
    if m.index >= m.timeline.assetCount - 10 and m.timeline.hasMore then m.timeline.callFunc("requestMore")
end sub

sub goNext()
    if m.index + 1 < m.timeline.assetCount
        showIndex(m.index + 1, manualFade())
    else if m.timeline.hasMore
        m.pendingNext = "manual"
        m.timeline.callFunc("requestMore")
    else
        showToast("This is the last photo")
    end if
end sub

sub goPrevious()
    if m.index > 0 then showIndex(m.index - 1, manualFade())
end sub

sub onAssetCountChanged()
    pending = m.pendingNext
    m.pendingNext = ""
    if pending = "manual"
        goNext()
    else if pending = "slideshow"
        slideshowAdvance()
    else
        assignPosters()  ' a neighbour may exist now: preload it
    end if
end sub

' ---- Posters: current plus preloaded neighbours ----

' Points the three posters at the previous, current and next item, reusing any already
' loaded. In a slideshow "next" is the next photo (videos are skipped), so it's ready in time.
sub assignPosters()
    count = m.timeline.assetCount
    nextIndex = m.index + 1
    if m.slideshow then nextIndex = nextPhotoIndex(m.index)
    wanted = []
    for each i in [m.index, nextIndex, m.index - 1]
        if i >= 0 and i < count then wanted.Push(i)
    end for

    ' Free posters holding something no longer wanted (freeSlot reuses the visible one last).
    for p = 0 to 2
        keep = false
        for each i in wanted
            if m.posterIndex[p] = i then keep = true
        end for
        if not keep then m.posterIndex[p] = -1
    end for

    for each i in wanted
        if posterSlotFor(i) < 0 then loadInto(freeSlot(), i)
    end for
end sub

' The next photo after index among the loaded items (looking up to 50 ahead), or -1.
function nextPhotoIndex(index as integer) as integer
    last = m.timeline.assetCount - 1
    if last > index + 50 then last = index + 50
    for i = index + 1 to last
        if not assetAt(i).isVideo then return i
    end for
    return -1
end function

function posterSlotFor(index as integer) as integer
    for p = 0 to 2
        if m.posterIndex[p] = index then return p
    end for
    return -1
end function

' A free slot, preferring one that isn't on screen.
function freeSlot() as integer
    fallback = -1
    for p = 0 to 2
        if m.posterIndex[p] = -1
            if m.shown = invalid or not m.posters[p].isSameNode(m.shown) then return p
            fallback = p
        end if
    end for
    return fallback
end function

sub loadInto(slot as integer, index as integer)
    poster = m.posters[slot]
    m.posterIndex[slot] = index
    if m.shown = invalid or not poster.isSameNode(m.shown)
        poster.opacity = 0
        settleKenBurns(poster, false)
    end if
    asset = assetAt(index)
    assetId = asset.assetId
    uri = thumbnailUrl(assetId, "preview")
    if poster.uri <> uri
        m.readyUri[poster.id] = ""
        fitPoster(poster, asset.ratio)
        poster.uri = uri
    end if
    if m.backsGroup.visible then m.backs[poster.id].uri = thumbnailUrl(assetId, "thumbnail")
end sub

' ---- Background behind photos that don't fill the screen (Settings > Photo background) ----

sub applyPhotoBackground(mode as string)
    dimmer = m.top.findNode("backsDim")
    if mode = "default"
        m.top.findNode("backdrop").color = "0x24232FFF"
    else
        m.top.findNode("backdrop").color = "0x000000FF"
    end if
    stretched = (mode = "glow" or mode = "blur")
    m.backsGroup.visible = stretched
    dimmer.visible = stretched
    if not stretched then return
    ' The photo's thumbnail, loaded tiny and stretched over the screen: the scaling blurs
    ' it, and smaller is softer. The glow is softer and dimmer than the blur.
    if mode = "glow"
        size = [24, 14]
        dimmer.color = "0x000000A0"
    else
        size = [96, 54]
        dimmer.color = "0x00000070"
    end if
    for each id in m.backs
        m.backs[id].loadWidth = size[0]
        m.backs[id].loadHeight = size[1]
    end for
end sub

' Each background fades in and out with its photo.
sub onPosterOpacity(event as object)
    m.backs[event.getRoSGNode().id].opacity = event.getData()
end sub

' Sizes the poster to the photo's shape, centred, so whatever is behind shows beside it.
' (A full-screen poster draws the empty sides itself.) Without a known ratio it fills the
' screen and letterboxes the photo inside.
sub fitPoster(poster as object, ratio as dynamic)
    width = 1920
    height = 1080
    if ratio <> invalid and ratio > 0
        if ratio >= 1920 / 1080
            height = Int(1920 / ratio + 0.5)
        else
            width = Int(1080 * ratio + 0.5)
        end if
    end if
    poster.width = width
    poster.height = height
    poster.loadWidth = width
    poster.loadHeight = height
    poster.translation = [Int((1920 - width) / 2), Int((1080 - height) / 2)]
end sub

function isReady(poster as object) as boolean
    return m.readyUri[poster.id] = poster.uri
end function

sub onPosterStatus(event as object)
    poster = event.getRoSGNode()
    status = event.getData()
    if status <> "ready" and status <> "failed" then return
    m.readyUri[poster.id] = poster.uri
    if m.target <> invalid and poster.isSameNode(m.target)
        if status = "failed"
            m.message.text = "Couldn't load this photo."
        else
            m.message.text = ""
        end if
        presentTarget()
    end if
end sub

' Crossfades from the poster on screen to the target poster.
sub presentTarget()
    target = m.target
    if m.shown <> invalid and target.isSameNode(m.shown)
        target.opacity = 1
    else
        m.fade.control = "stop"
        frame = target.getParent()
        m.stage.removeChild(frame)
        m.stage.appendChild(frame)
        back = m.backs[target.id]
        m.backsGroup.removeChild(back)
        m.backsGroup.appendChild(back)
        for each poster in m.posters
            if not poster.isSameNode(target) and (m.shown = invalid or not poster.isSameNode(m.shown)) then poster.opacity = 0
        end for

        if m.fadeSeconds <= 0
            target.opacity = 1
            if m.shown <> invalid then m.shown.opacity = 0
        else
            m.fadeIn.fieldToInterp = target.id + ".opacity"
            m.fadeIn.keyValue = [target.opacity, 1.0]
            if m.shown <> invalid
                m.fadeOut.fieldToInterp = m.shown.id + ".opacity"
                m.fadeOut.keyValue = [m.shown.opacity, 0.0]
            else
                m.fadeOut.fieldToInterp = "fadeDummy.opacity"
            end if
            m.fade.duration = m.fadeSeconds
            m.fade.control = "start"
        end if
        if m.slideshow then startKenBurns(target) else settleKenBurns(target, false)
        m.shown = target
    end if
    if m.slideshow then restartSlideTimer()
    updateNames()
end sub

' ---- Slideshow ----

sub toggleSlideshow()
    if m.slideshow
        stopSlideshow("Slideshow off")
        return
    end if
    m.slideshow = true
    assignPosters()  ' preload the next photo rather than the next item
    seconds = loadSlideshowSeconds()
    m.slideTimer.duration = seconds
    showToast("Slideshow on  -  " + seconds.ToStr() + " seconds per photo")
    if assetAt(m.index).isVideo
        slideshowAdvance()
    else
        restartSlideTimer()
        if m.shown <> invalid then startKenBurns(m.shown)
    end if
end sub

sub stopSlideshow(message as string)
    m.slideshow = false
    m.slideTimer.control = "stop"
    m.pendingNext = ""
    m.ring.stop = true
    m.ring.visible = false
    if m.shown <> invalid then settleKenBurns(m.shown, true)
    showToast(message)
end sub

sub restartSlideTimer()
    m.slideTimer.control = "stop"
    m.slideTimer.control = "start"
    m.ring.visible = true
    m.ring.countdown = m.slideTimer.duration
end sub

sub onSlideTimer()
    if m.slideshow then slideshowAdvance()
end sub

' Next photo (videos skipped); loops to the start after the last one.
sub slideshowAdvance()
    count = m.timeline.assetCount
    i = m.index
    for steps = 1 to count
        i = i + 1
        if i >= count
            if m.timeline.hasMore
                m.pendingNext = "slideshow"
                m.timeline.callFunc("requestMore")
                return
            end if
            i = 0
        end if
        if not assetAt(i).isVideo
            showIndex(i, slideshowFade())
            return
        end if
    end for
    stopSlideshow("No photos to show in a slideshow")
end sub

' ---- Ken Burns (slideshow only) ----

' One animation per poster, so the outgoing photo keeps moving while it fades out.
function createKenBurns(poster as object) as object
    anim = m.top.createChild("Animation")
    scale = anim.createChild("Vector2DFieldInterpolator")
    scale.key = [0.0, 1.0]
    scale.fieldToInterp = poster.getParent().id + ".scale"
    move = anim.createChild("Vector2DFieldInterpolator")
    move.key = [0.0, 1.0]
    move.fieldToInterp = poster.getParent().id + ".translation"
    return { anim: anim, scale: scale, move: move }
end function

' A slow, subtle zoom in, zoom out or pan across (5%), lasting through the next crossfade.
sub startKenBurns(poster as object)
    zoom = 1.05
    ' Room to pan at full zoom without showing the edge of a full-screen photo.
    roomX = Int((zoom - 1) * 960)
    roomY = Int((zoom - 1) * 540)
    x = randomBetween(roomX \ 2, roomX)
    if Rnd(2) = 1 then x = -x
    point = [x, randomBetween(-roomY, roomY)]
    style = Rnd(3)
    if style = 1
        scales = [[1.0, 1.0], [zoom, zoom]]
        moves = [[0, 0], point]
    else if style = 2
        scales = [[zoom, zoom], [1.0, 1.0]]
        moves = [point, [0, 0]]
    else
        scales = [[zoom, zoom], [zoom, zoom]]
        moves = [point, [-point[0], -point[1]]]
    end if

    kb = m.kenBurns[poster.id]
    kb.anim.control = "stop"
    kb.anim.easeFunction = "linear"
    kb.scale.keyValue = scales
    kb.move.keyValue = moves
    kb.anim.duration = loadSlideshowSeconds() + slideshowFade() + 1
    kb.anim.control = "start"
end sub

' Back to the plain full-screen fit: eased when the slideshow stops, at once otherwise.
sub settleKenBurns(poster as object, animate as boolean)
    kb = m.kenBurns[poster.id]
    kb.anim.control = "stop"
    if animate
        kb.anim.easeFunction = "outQuad"
        kb.scale.keyValue = [poster.getParent().scale, [1.0, 1.0]]
        kb.move.keyValue = [poster.getParent().translation, [0, 0]]
        kb.anim.duration = 0.6
        kb.anim.control = "start"
    else
        poster.getParent().scale = [1.0, 1.0]
        poster.getParent().translation = [0, 0]
    end if
end sub

function randomBetween(low as integer, high as integer) as integer
    return low + Rnd(high - low + 1) - 1
end function

' ---- Asset details: info overlay and people's names ----

sub toggleInfo()
    m.info.visible = not m.info.visible
    if m.info.visible then loadDetails()
    updateNames()
end sub

sub loadDetails()
    assetId = assetAt(m.index).assetId
    if m.infoCache.DoesExist(assetId)
        renderInfo(m.infoCache[assetId])
        return
    end if
    renderInfo({ date: "Loading...", place: "", camera: "", name: "" })
    m.infoTask = startApiRequest(currentSettings(), "GET", "/api/assets/" + assetId, "onInfo")
end sub

sub onInfo(event as object)
    resp = event.getData()
    m.infoTask = invalid
    if not resp.ok
        renderInfo({ date: describeApiError(resp), place: "", camera: "", name: "" })
        return
    end if
    summary = summarizeAsset(resp.data)
    m.infoCache[resp.data.id] = summary
    if resp.data.id = assetAt(m.index).assetId
        renderInfo(summary)
        updateNames()
    end if
end sub

' Names of the people in the photo on screen (hidden under the info overlay). They change
' when the new photo appears, not when it starts loading.
sub updateNames()
    m.names.visible = m.showPeople and not m.info.visible
    if not m.showPeople then return
    text = ""
    summary = m.infoCache[assetAt(m.index).assetId]
    if summary <> invalid and m.shown <> invalid and m.shown.isSameNode(m.target) then text = summary.people
    m.namesText.text = text
    m.namesShadow.text = text
end sub

function summarizeAsset(data as object) as object
    exif = data.exifInfo
    if exif = invalid then exif = {}

    camera = exif.model
    if exif.make <> invalid and camera <> invalid and Left(camera, Len(exif.make)) <> exif.make
        camera = exif.make + " " + camera
    end if
    exposure = []
    ' Cameras record 0 for values they don't know.
    if exif.fNumber <> invalid and exif.fNumber > 0 then exposure.Push("f/" + formatOneDecimal(exif.fNumber))
    if exif.exposureTime <> invalid and exif.exposureTime <> "" then exposure.Push(exif.exposureTime + " s")
    if exif.iso <> invalid and exif.iso > 0 then exposure.Push("ISO " + exif.iso.ToStr())
    if exif.focalLength <> invalid and exif.focalLength > 0 then exposure.Push(formatOneDecimal(exif.focalLength) + " mm")

    names = []
    if data.people <> invalid
        for each person in data.people
            hidden = (person.isHidden <> invalid and person.isHidden)
            if person.name <> invalid and person.name <> "" and not hidden then names.Push(person.name)
        end for
    end if

    return {
        date: formatPhotoDate(data.localDateTime)
        people: joinNonEmpty(names, ", ")
        place: joinNonEmpty([exif.city, exif.state, exif.country], ", ")
        camera: joinNonEmpty([camera, joinNonEmpty(exposure, "   ")], "      ")
        name: data.originalFileName
    }
end function

sub renderInfo(summary as object)
    m.top.findNode("infoDate").text = summary.date
    m.top.findNode("infoPlace").text = summary.place
    m.top.findNode("infoCamera").text = summary.camera
    m.top.findNode("infoName").text = summary.name
end sub

' ---- Toast ----

sub showToast(text as string)
    m.toastText.text = text
    m.top.findNode("toastBack").width = m.toastText.boundingRect().width + 48
    m.toastAnim.control = "stop"
    m.toastAnim.control = "start"
end sub

' ---- Keys ----

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    asset = assetAt(m.index)
    if key = "right"
        goNext()
    else if key = "left"
        goPrevious()
    else if (key = "OK" or key = "play") and asset.isVideo
        playVideo(asset)
    else if key = "OK" or key = "up" or key = "down"
        toggleInfo()
    else if key = "play"
        toggleSlideshow()
    else if key = "back"
        close()
        return false  ' MainScene pops the screen
    else
        return false
    end if
    return true
end function

sub playVideo(asset as object)
    if m.slideshow then stopSlideshow("Slideshow off")
    m.top.navigate = { screen: "VideoPlayer", params: { asset: asset } }
end sub

sub close()
    m.slideshow = false
    m.slideTimer.control = "stop"
    m.fade.control = "stop"
    m.ring.stop = true
    for each id in m.kenBurns
        m.kenBurns[id].anim.control = "stop"
    end for
    m.timeline.unobserveFieldScoped("assetCount")
    m.timeline.jumpToIndex = m.index
end sub

sub onLowMemory()
    m.infoCache = {}
end sub
