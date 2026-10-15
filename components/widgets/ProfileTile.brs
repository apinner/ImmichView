' Circle colours, from the logo's purples; users take them in turn.
function tileColors() as object
    return ["0x8B57C3FF", "0x6E3997FF", "0xA274D4FF", "0x572C78FF", "0x7E4FB8FF"]
end function

sub init()
    m.ring = m.top.findNode("ring")
    m.circle = m.top.findNode("circle")
    m.initial = m.top.findNode("initial")
    m.lock = m.top.findNode("lock")
    m.name = m.top.findNode("name")
    m.photoMask = m.top.findNode("photoMask")
    m.photo = m.top.findNode("photo")
    m.photo.observeField("loadStatus", "onPhotoStatus")
    m.item = invalid
end sub

sub onContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    ' The picker fills in photoUrl when Immich answers, so follow it on this item.
    if m.item <> invalid then m.item.unobserveFieldScoped("photoUrl")
    m.item = item
    if not item.isAdd then item.observeFieldScoped("photoUrl", "showPhoto")
    showPhoto()
    m.name.text = item.title
    if item.isAdd
        m.initial.text = "+"
        m.circle.blendColor = "0x3A3950FF"
    else
        m.initial.text = UCase(Left(item.title, 1))
        colors = tileColors()
        m.circle.blendColor = colors[item.colorIndex MOD colors.Count()]
    end if
    m.lock.visible = item.hasPin
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

' The user's Immich profile photo, loaded with their own server and key.
sub showPhoto()
    url = ""
    if m.item <> invalid and not m.item.isAdd and m.item.photoUrl <> invalid then url = m.item.photoUrl
    if url = m.photo.uri then return
    m.photoMask.visible = false
    if url <> "" then m.photo.setHttpAgent(createAuthAgentFor(m.item.serverUrl, m.item.apiKey))
    m.photo.uri = url
end sub

' The initial shows until the photo has loaded, and stays if it can't be.
sub onPhotoStatus()
    m.photoMask.visible = (m.photo.loadStatus = "ready" and m.photo.uri <> "")
end sub
