sub init()
    m.video = m.top.findNode("video")
    m.error = m.top.findNode("error")
    m.video.setHttpAgent(createAuthAgent())
    m.video.observeField("state", "onStateChanged")
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
    if state = "playing" and not m.top.playbackStarted
        m.top.playbackStarted = true
    else if state = "finished"
        m.top.done = true
    else if state = "error"
        logDebug("video error " + m.video.errorCode.ToStr() + ": " + m.video.errorMsg)
        showError()
    end if
end sub

sub showError()
    text = "This video couldn't be played (" + m.video.errorMsg + ")."
    if not canDecodeHevc()
        text = text + Chr(10) + Chr(10) + "This Roku can't play HEVC (H.265) video. In Immich, go to Administration > Settings > Video Transcoding and set the transcode policy so HEVC videos are converted to H.264, then run the transcode job."
    end if
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
        m.video.control = "stop"
        return false  ' MainScene pops the screen
    end if
    return false
end function
