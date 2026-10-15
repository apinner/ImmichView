sub init()
    m.video = m.top.findNode("video")
    m.error = m.top.findNode("error")
    m.video.setHttpAgent(createAuthAgent())
    m.video.observeField("state", "onStateChanged")
    m.pictureCheck = m.top.findNode("pictureCheck")
    m.pictureCheck.observeField("fire", "onPictureCheck")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() and not m.error.visible then m.video.setFocus(true)
end sub

sub onAssetSet()
    asset = m.top.asset
    content = CreateObject("roSGNode", "ContentNode")
    ' /video/playback serves Immich's transcode when there is one, else the original,
    ' and supports byte ranges (needed for seeking).
    content.url = m.global.serverUrl + "/api/assets/" + asset.assetId + "/video/playback"
    content.streamFormat = "mp4"
    m.video.content = content
    m.video.control = "play"
    logDebug("play video " + asset.assetId)
end sub

sub onStateChanged()
    state = m.video.state
    logDebug("video state: " + state)
    ' After an error Roku can also report "finished"; keep the error message on screen.
    if m.error.visible then return
    if state = "playing" and not m.top.playbackStarted
        m.top.playbackStarted = true
        m.pictureCheck.control = "start"
    else if state = "finished"
        m.top.done = true
    else if state = "error"
        logDebug("video error " + m.video.errorCode.ToStr() + ": " + m.video.errorMsg)
        showError()
    end if
end sub

' Roku plays files whose video track it can't decode (e.g. VP9 in MP4) as sound over a
' black screen, without an error. Stop and explain instead.
sub onPictureCheck()
    format = m.video.videoFormat
    if format = invalid then return
    logDebug("video format: " + format)
    if format <> "" and LCase(format) <> "none" then return
    m.video.control = "stop"
    showMessage("This video has sound but no picture on this Roku: its video format isn't supported." + Chr(10) + Chr(10) + "Immich can convert it to one that plays everywhere. In Immich, go to Administration > Settings > Video Transcoding, keep H.264 as the only accepted video codec, then run Jobs > Transcode Videos > Missing.")
end sub

sub showError()
    text = "This video couldn't be played (" + m.video.errorMsg + ")."
    if not canDecodeHevc()
        text = text + Chr(10) + Chr(10) + "This Roku can't play HEVC (H.265) video. In Immich, go to Administration > Settings > Video Transcoding and set the transcode policy so HEVC videos are converted to H.264, then run the transcode job."
    else if m.video.errorCode = -5
        ' e.g. a 1080x1920 portrait original: too tall for the Roku decoder
        text = text + Chr(10) + Chr(10) + "Immich can convert it to a size and format that plays everywhere. In Immich, go to Administration > Settings > Video Transcoding, set the target resolution to 720p with H.264 as the only accepted video codec, then run Jobs > Transcode Videos > Missing."
    end if
    showMessage(text)
end sub

' Replaces the video with a message; Back returns.
sub showMessage(text as string)
    text = text + Chr(10) + Chr(10) + "Press Back to return."
    m.error.text = text
    m.error.visible = true
    m.video.visible = false
    m.top.setFocus(true)
    m.top.playbackStarted = true  ' playback attempt is over: lets a deep-linked launch complete
end sub

function canDecodeHevc() as boolean
    result = CreateObject("roDeviceInfo").CanDecodeVideo({ Codec: "hevc" })
    return result.result = true
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back"
        m.pictureCheck.control = "stop"
        m.video.control = "stop"
        return false  ' MainScene pops the screen
    end if
    return false
end function
