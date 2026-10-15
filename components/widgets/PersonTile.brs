' Retries for a face image that fails to load.
function maxFaceRetries() as integer
    return 3
end function

sub init()
    m.ring = m.top.findNode("ring")
    m.face = m.top.findNode("face")
    m.name = m.top.findNode("name")
    m.face.setHttpAgent(createAuthAgent())
    m.face.observeField("loadStatus", "onFaceStatus")
    m.retryTimer = m.top.findNode("retryTimer")
    m.retryTimer.observeField("fire", "onRetry")
    m.faceUri = ""
    m.retries = 0
end sub

sub onContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    m.retryTimer.control = "stop"
    m.faceUri = item.thumbUrl
    m.retries = 0
    m.face.uri = m.faceUri
    m.name.text = item.title
end sub

' When a screenful of faces loads at once, Roku sometimes drops a few: try those again.
sub onFaceStatus()
    if m.face.loadStatus <> "failed" or m.face.uri <> m.faceUri then return
    if m.retries >= maxFaceRetries() then return
    m.retries = m.retries + 1
    logDebug("face failed, retry " + m.retries.ToStr() + ": " + m.top.itemContent.title)
    m.retryTimer.control = "start"
end sub

sub onRetry()
    m.face.uri = ""
    m.face.uri = m.faceUri
end sub

sub onFocusChanged()
    focus = 0.0
    if m.top.gridHasFocus then focus = m.top.focusPercent
    m.ring.opacity = focus
    if focus > 0.5
        m.name.color = "0xFFFFFFFF"
    else
        m.name.color = "0xA0A8B0FF"
    end if
end sub
