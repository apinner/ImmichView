' Roku's decoder limits (developer.roku.com "Streaming specifications"): H.264 up to 1920x1080,
' HEVC up to 3840x2160 and only on 4K models. Portrait 1080x1920 H.264 fails ("Image height too
' high"), so the frame must fit within these in both directions.
function decoderLimits(codec as string) as object
    if codec = "hevc" then return { w: 3840, h: 2160 }
    return { w: 1920, h: 1080 }
end function

sub init()
    m.video = m.top.findNode("video")
    m.error = m.top.findNode("error")
    m.video.setHttpAgent(createAuthAgent())
    m.video.observeField("state", "onStateChanged")
    m.pictureCheck = m.top.findNode("pictureCheck")
    m.pictureCheck.observeField("fire", "onPictureCheck")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.candidates = []       ' HLS variants still to try: { codec, w, h, url }
    m.current = invalid     ' the variant (or mp4) playing now
    m.sessionPath = ""      ' /api/assets/<id>/video/stream/<session>, to end the session
    m.ignoreFinished = false
end sub

sub onFocusChanged()
    if m.top.hasFocus() and not m.error.visible then m.video.setFocus(true)
end sub

' ---- Choosing a stream ----
' The stored transcode (/video/playback) plays first: it reliably has sound. If it can't play
' (portrait taller than 1080, VP9...), Immich's real-time transcoding is asked for variants
' (main.m3u8: 480/720/1080... in H.264 and HEVC) and the largest this Roku can decode plays.
' Roku reports no audio track for those HLS streams (unconfirmed whether they're silent).

sub onAssetSet()
    m.assetId = m.top.asset.assetId
    m.triedRealtime = false
    logDebug("play video " + m.assetId)
    playStoredTranscode()
end sub

' The stored copy didn't play (e.g. portrait taller than 1080, or VP9): ask for real-time variants.
sub requestRealtime()
    m.triedRealtime = true
    m.video.control = "stop"
    m.ignoreFinished = true  ' Roku reports "finished" after an error
    m.streamTask = startApiRequest(currentSettings(), "GET", streamBase() + "/main.m3u8", "onMainPlaylist", invalid, 15000, true)
end sub

function streamBase() as string
    return "/api/assets/" + m.assetId + "/video/stream"
end function

sub onMainPlaylist(event as object)
    resp = event.getData()
    m.streamTask = invalid
    m.candidates = []
    if resp.ok then m.candidates = playableVariants(parseVariants(resp.data))
    if m.candidates.Count() = 0
        logDebug("no real-time stream (" + resp.status.ToStr() + ")")
        showError()
        return
    end if
    playNextCandidate()
end sub

' #EXT-X-STREAM-INF lines: RESOLUTION=WxH, CODECS="avc1...|hvc1..."; the next line is its URI.
function parseVariants(text as string) as object
    variants = []
    pending = invalid
    sizeRe = CreateObject("roRegex", "RESOLUTION=(\d+)x(\d+)", "")
    for each line in text.Split(Chr(10))
        line = line.Trim()
        if Left(line, 18) = "#EXT-X-STREAM-INF:"
            size = sizeRe.Match(line)
            codec = ""
            lower = LCase(line)
            if lower.InStr("hvc1") >= 0 or lower.InStr("hev1") >= 0 then codec = "hevc"
            if lower.InStr("avc1") >= 0 then codec = "avc"
            pending = invalid
            if size.Count() = 3 and codec <> "" then pending = { codec: codec, w: size[1].ToInt(), h: size[2].ToInt() }
        else if line <> "" and Left(line, 1) <> "#" and pending <> invalid
            pending.url = line
            variants.Push(pending)
            pending = invalid
        end if
    end for
    return variants
end function

' Variants this Roku can decode, best first (most pixels; H.264 before HEVC at the same size,
' as it's the more dependable decoder).
function playableVariants(variants as object) as object
    hevc = canDecodeHevc()
    result = []
    for each v in variants
        limits = decoderLimits(v.codec)
        if (v.codec = "avc" or hevc) and v.w <= limits.w and v.h <= limits.h
            v.score = v.w * v.h * 2
            if v.codec = "avc" then v.score = v.score + 1
            result.Push(v)
        end if
    end for
    result.SortBy("score", "r")
    return result
end function

sub playNextCandidate()
    v = m.candidates.Shift()
    m.current = v
    ' Variant URIs are relative to main.m3u8: "<session>/<index>/playlist.m3u8".
    m.sessionPath = streamBase() + "/" + v.url.Split("/")[0]
    logDebug("hls variant " + v.codec + " " + v.w.ToStr() + "x" + v.h.ToStr())
    play(m.global.serverUrl + streamBase() + "/" + v.url, "hls")
end sub

' /video/playback serves Immich's stored transcode when there is one, else the original, with
' byte ranges for seeking.
sub playStoredTranscode()
    m.current = { codec: "mp4" }
    play(m.global.serverUrl + "/api/assets/" + m.assetId + "/video/playback", "mp4")
end sub

sub play(url as string, format as string)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = format
    m.video.content = content
    m.video.control = "play"
end sub

' A variant that won't play: try the next (skipping ones of the same codec at least as tall),
' then the stored transcode, then explain.
function tryAnotherStream() as boolean
    failed = m.current
    if failed = invalid then return false
    if failed.codec = "mp4"
        if m.triedRealtime then return false
        requestRealtime()
        return true
    end if
    remaining = []
    for each v in m.candidates
        if v.codec <> failed.codec or v.h < failed.h then remaining.Push(v)
    end for
    m.candidates = remaining
    m.ignoreFinished = true  ' Roku reports "finished" after an error
    if m.candidates.Count() = 0 then return false
    playNextCandidate()
    return true
end function

' Releases the server's real-time transcoding for this video.
sub endSession()
    if m.sessionPath = "" then return
    m.endTask = startApiRequest(currentSettings(), "DELETE", m.sessionPath, "onSessionEnded")
    m.sessionPath = ""
end sub

sub onSessionEnded()
    m.endTask = invalid
end sub

' ---- Playback state ----

sub onStateChanged()
    state = m.video.state
    logDebug("video state: " + state)
    ' After an error Roku can also report "finished"; keep the error message on screen.
    if m.error.visible then return
    if state = "playing"
        m.ignoreFinished = false
        if not m.top.playbackStarted
            m.top.playbackStarted = true
            m.pictureCheck.control = "start"
        end if
    else if state = "finished"
        if m.ignoreFinished then return
        endSession()
        m.top.done = true
    else if state = "error"
        logDebug("video error " + m.video.errorCode.ToStr() + ": " + m.video.errorMsg)
        if tryAnotherStream() then return
        showError()
    end if
end sub

' Roku plays files whose video track it can't decode (e.g. VP9 in MP4) as sound over a
' black screen, without an error. Try another stream, else stop and explain.
sub onPictureCheck()
    format = m.video.videoFormat
    if format = invalid then return
    logDebug("video format: " + format)
    tracks = m.video.availableAudioTracks
    if tracks <> invalid then logDebug("audio tracks: " + FormatJson(tracks) + " audioFormat: " + m.video.audioFormat)
    if format <> "" and LCase(format) <> "none" then return
    m.top.playbackStarted = false
    if tryAnotherStream() then return
    m.video.control = "stop"
    showMessage("This video has sound but no picture on this Roku: its video format isn't supported." + Chr(10) + Chr(10) + transcodeAdvice())
end sub

sub showError()
    text = "This video couldn't be played (" + m.video.errorMsg + ")."
    if not canDecodeHevc()
        text = text + Chr(10) + Chr(10) + "This Roku can't play HEVC (H.265) video. In Immich, go to Administration > Settings > Video Transcoding and set the transcode policy so HEVC videos are converted to H.264, then run the transcode job."
    else if m.video.errorCode = -5
        text = text + Chr(10) + Chr(10) + transcodeAdvice()
    end if
    showMessage(text)
end sub

' Replaces the video with a message; Back returns.
sub showMessage(text as string)
    endSession()
    text = text + Chr(10) + Chr(10) + "Press Back to return."
    m.error.text = text
    m.error.visible = true
    m.video.visible = false
    m.top.setFocus(true)
    m.top.playbackStarted = true  ' playback attempt is over: lets a deep-linked launch complete
end sub

' Roku can't play H.264 taller than 1080 px (e.g. portrait videos). Immich's real-time
' transcoding makes a size that fits on demand, without changing stored transcodes.
function transcodeAdvice() as string
    return "Roku can't play this video's size or format as stored. In Immich, turn on real-time transcoding (Administration > Settings > Video Transcoding) with H.264 and the 480p, 720p and 1080p resolutions; ImmichView then picks a version this Roku can play."
end function

function canDecodeHevc() as boolean
    result = CreateObject("roDeviceInfo").CanDecodeVideo({ Codec: "hevc" })
    return result.result = true
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back"
        m.pictureCheck.control = "stop"
        m.video.control = "stop"
        endSession()
        return false  ' MainScene pops the screen
    end if
    return false
end function
