' Slow zoom/drift needs a few seconds to read as motion rather than a jump.
function minSecondsPerPhoto() as integer
    return 8
end function

function batchSize() as integer
    return 50
end function

sub init()
    m.top.backgroundUri = ""
    m.top.backgroundColor = "0x000000FF"
    m.stage = m.top.findNode("stage")
    m.posters = [m.top.findNode("photoA"), m.top.findNode("photoB")]
    m.caption = m.top.findNode("caption")
    m.message = m.top.findNode("message")
    m.fade = m.top.findNode("fade")
    m.drift = m.top.findNode("drift")
    m.advanceTimer = m.top.findNode("advanceTimer")
    m.retryTimer = m.top.findNode("retryTimer")
    m.moveMessageTimer = m.top.findNode("moveMessageTimer")
    m.advanceTimer.observeField("fire", "showNext")
    m.retryTimer.observeField("fire", "onRetry")
    m.moveMessageTimer.observeField("fire", "moveMessage")

    m.queue = []          ' slides waiting: { id, date, place }
    m.memorySlides = invalid
    m.frontIndex = -1     ' poster on screen
    m.pending = invalid   ' slide loading into the back poster
    m.loading = false
    m.waitingForPhotos = true
    m.failures = 0
    m.corner = 0

    profile = loadSettings()
    if not hasSettings(profile)
        showMessage("Open ImmichView on this Roku to choose whose photos to show.")
        return
    end if
    m.global.addFields({ serverUrl: profile.serverUrl, apiKey: profile.apiKey })
    agent = createAuthAgent()
    for each poster in m.posters
        poster.setHttpAgent(agent)
        poster.observeField("loadStatus", "onPosterStatus")
    end for

    m.settings = loadScreensaverSettings()
    m.secondsPerPhoto = loadSlideshowSeconds()
    if m.secondsPerPhoto < minSecondsPerPhoto() then m.secondsPerPhoto = minSecondsPerPhoto()
    m.advanceTimer.duration = m.secondsPerPhoto
    fetchBatch()
end sub

' ---- Fetching photos ----

sub fetchBatch()
    if m.loading then return
    m.loading = true
    if m.settings.source = "memories"
        m.task = startApiRequest(currentSettings(), "GET", "/api/memories?for=" + todayIso(), "onMemories")
        return
    end if
    body = { size: batchSize(), type: "IMAGE", withExif: true }
    if m.settings.source = "album" and m.settings.albumId <> ""
        body.albumIds = [m.settings.albumId]
    else
        body.visibility = "timeline"
    end if
    m.task = startApiRequest(currentSettings(), "POST", "/api/search/random", "onRandom", body)
end sub

function todayIso() as string
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    return Left(dt.ToISOString(), 10)
end function

sub onRandom(event as object)
    resp = event.getData()
    m.loading = false
    m.task = invalid
    if not resp.ok
        showError(resp)
        return
    end if
    if resp.data.Count() = 0
        fallBackToRandom()
        return
    end if
    for each asset in resp.data
        m.queue.Push(makeSlide(asset, ""))
    end for
    photosArrived()
end sub

sub onMemories(event as object)
    resp = event.getData()
    m.loading = false
    m.task = invalid
    if not resp.ok
        showError(resp)
        return
    end if
    slides = []
    for each memory in resp.data
        note = ""
        if memory.data <> invalid and memory.data.year <> invalid then note = "On this day in " + memory.data.year.ToStr()
        for each asset in memory.assets
            if asset.type = "IMAGE" then slides.Push(makeSlide(asset, note))
        end for
    end for
    if slides.Count() = 0
        fallBackToRandom()
        return
    end if
    m.memorySlides = slides
    m.queue = shuffled(slides)
    photosArrived()
end sub

' Nothing to show from the chosen album or memories: use random library photos instead.
sub fallBackToRandom()
    logDebug("screensaver source empty, using random photos")
    m.settings.source = "random"
    fetchBatch()
end sub

function makeSlide(asset as object, note as string) as object
    exif = asset.exifInfo
    if exif = invalid then exif = {}
    place = joinNonEmpty([exif.city, exif.country], ", ")
    return { id: asset.id, date: formatShortDate(asset.localDateTime), place: joinNonEmpty([place, note], "  -  ") }
end function

function shuffled(items as object) as object
    result = []
    for each item in items
        result.Push(item)
    end for
    for i = result.Count() - 1 to 1 step -1
        j = Rnd(i + 1) - 1
        swap = result[i]
        result[i] = result[j]
        result[j] = swap
    end for
    return result
end function

sub photosArrived()
    hideMessage()
    if m.waitingForPhotos
        m.waitingForPhotos = false
        showNext()
    end if
end sub

' ---- Showing photos ----

sub showNext()
    if m.queue.Count() = 0
        if m.memorySlides <> invalid
            m.queue = shuffled(m.memorySlides)
        else
            m.waitingForPhotos = true
            fetchBatch()
            return
        end if
    end if
    if m.queue.Count() < 5 and m.memorySlides = invalid then fetchBatch()

    m.pending = m.queue.Shift()
    back = m.posters[backIndex()]
    uri = thumbnailUrl(m.pending.id, "preview")
    if back.uri = uri and back.loadStatus = "ready"
        presentPending()
    else
        back.opacity = 0
        back.uri = uri
    end if
end sub

function backIndex() as integer
    if m.frontIndex = 0 then return 1
    return 0
end function

sub onPosterStatus(event as object)
    if m.pending = invalid or not event.getRoSGNode().isSameNode(m.posters[backIndex()]) then return
    status = event.getData()
    if status = "ready"
        presentPending()
    else if status = "failed"
        m.failures = m.failures + 1
        m.pending = invalid
        if m.failures >= 5
            showMessage("Couldn't load photos from Immich. Trying again in a minute.")
            m.retryTimer.control = "start"
        else
            showNext()
        end if
    end if
end sub

sub presentPending()
    slide = m.pending
    m.pending = invalid
    m.failures = 0
    back = m.posters[backIndex()]

    back.scale = [1.0, 1.0]
    back.translation = [0, 0]
    m.stage.removeChild(back)
    m.stage.appendChild(back)
    updateCaption(slide)

    m.fade.control = "stop"
    m.top.findNode("fadeIn").fieldToInterp = back.id + ".opacity"
    fadeOut = m.top.findNode("fadeOut")
    if m.frontIndex >= 0
        fadeOut.fieldToInterp = m.posters[m.frontIndex].id + ".opacity"
    else
        fadeOut.fieldToInterp = "fadeDummy.opacity"
    end if
    m.fade.control = "start"
    startDrift(back)

    m.frontIndex = backIndex()
    m.advanceTimer.control = "stop"
    m.advanceTimer.control = "start"
end sub

' Slow zoom in or out plus a small shift, so nothing sits still on screen.
sub startDrift(poster as object)
    if Rnd(2) = 1
        scales = [[1.0, 1.0], [1.08, 1.08]]
    else
        scales = [[1.08, 1.08], [1.0, 1.0]]
    end if
    m.drift.control = "stop"
    driftScale = m.top.findNode("driftScale")
    driftMove = m.top.findNode("driftMove")
    driftScale.fieldToInterp = poster.id + ".scale"
    driftScale.keyValue = scales
    driftMove.fieldToInterp = poster.id + ".translation"
    driftMove.keyValue = [[randomBetween(-30, 30), randomBetween(-20, 20)], [randomBetween(-30, 30), randomBetween(-20, 20)]]
    m.drift.duration = m.secondsPerPhoto + 2
    m.drift.control = "start"
end sub

function randomBetween(low as integer, high as integer) as integer
    return low + Rnd(high - low + 1) - 1
end function

' Date and place in a different corner for each photo.
sub updateCaption(slide as object)
    m.caption.opacity = 0
    show = m.settings.showCaption and slide.date <> ""
    m.top.findNode("captionFade").fieldToInterp = "caption.opacity"
    m.caption.visible = show
    if not show then return

    dateLabel = m.top.findNode("captionDate")
    placeLabel = m.top.findNode("captionPlace")
    dateLabel.text = slide.date
    placeLabel.text = slide.place
    width = dateLabel.boundingRect().width
    if placeLabel.boundingRect().width > width then width = placeLabel.boundingRect().width
    width = width + 48
    height = 70
    if slide.place <> "" then height = 108

    back = m.top.findNode("captionBack")
    back.width = width
    back.height = height

    m.corner = (m.corner + 1) MOD 4
    x = 80
    y = 80
    if m.corner = 1 or m.corner = 2 then x = 1920 - 80 - width
    if m.corner >= 2 then y = 1080 - 80 - height
    m.caption.translation = [x, y]
end sub

' ---- Messages and errors ----

sub showError(resp as object)
    showMessage(describeApiError(resp) + Chr(10) + Chr(10) + "Trying again in a minute.")
    m.waitingForPhotos = true
    m.retryTimer.control = "start"
end sub

sub onRetry()
    m.failures = 0
    if m.queue.Count() > 0
        m.waitingForPhotos = false
        showNext()
    else
        fetchBatch()
    end if
end sub

sub showMessage(text as string)
    m.message.text = text
    m.message.visible = true
    moveMessage()
    m.moveMessageTimer.control = "start"
end sub

sub hideMessage()
    m.message.visible = false
    m.moveMessageTimer.control = "stop"
end sub

' Messages move around too, against burn-in.
sub moveMessage()
    m.message.translation = [randomBetween(80, 840), randomBetween(80, 860)]
end sub
