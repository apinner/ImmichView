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

    agent = createAuthAgent()
    m.posters = []
    m.posterIndex = []      ' asset index each poster holds, -1 if none
    m.readyUri = {}         ' poster id -> uri that finished loading
    for each id in ["p0", "p1", "p2"]
        poster = m.top.findNode(id)
        poster.setHttpAgent(agent)
        poster.observeField("loadStatus", "onPosterStatus")
        m.posters.Push(poster)
        m.posterIndex.Push(-1)
        m.readyUri[id] = ""
    end for

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

    if isReady(m.target)
        m.message.text = ""
        presentTarget()
    else
        m.message.text = "Loading..."
    end if
    if m.info.visible then loadInfo()

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

' Points the three posters at index-1, index and index+1, reusing any already loaded.
sub assignPosters()
    count = m.timeline.assetCount
    wanted = []
    for each i in [m.index, m.index + 1, m.index - 1]
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
    if m.shown = invalid or not poster.isSameNode(m.shown) then poster.opacity = 0
    uri = thumbnailUrl(assetAt(index).assetId, "preview")
    if poster.uri <> uri
        m.readyUri[poster.id] = ""
        poster.uri = uri
    end if
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
        m.stage.removeChild(target)
        m.stage.appendChild(target)
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
        m.shown = target
    end if
    if m.slideshow then restartSlideTimer()
end sub

' ---- Slideshow ----

sub toggleSlideshow()
    if m.slideshow
        stopSlideshow("Slideshow off")
        return
    end if
    m.slideshow = true
    seconds = loadSlideshowSeconds()
    m.slideTimer.duration = seconds
    showToast("Slideshow on  -  " + seconds.ToStr() + " seconds per photo")
    if assetAt(m.index).isVideo
        slideshowAdvance()
    else
        restartSlideTimer()
    end if
end sub

sub stopSlideshow(message as string)
    m.slideshow = false
    m.slideTimer.control = "stop"
    m.pendingNext = ""
    showToast(message)
end sub

sub restartSlideTimer()
    m.slideTimer.control = "stop"
    m.slideTimer.control = "start"
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

' ---- Info overlay ----

sub toggleInfo()
    m.info.visible = not m.info.visible
    if m.info.visible then loadInfo()
end sub

sub loadInfo()
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
    if resp.data.id = assetAt(m.index).assetId then renderInfo(summary)
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

    return {
        date: formatPhotoDate(data.localDateTime)
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
    m.timeline.unobserveFieldScoped("assetCount")
    m.timeline.jumpToIndex = m.index
end sub
