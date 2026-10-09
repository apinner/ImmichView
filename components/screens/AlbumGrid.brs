' Loads more when focus gets within this many items of the end of what's loaded.
function loadAheadItems() as integer
    return 36
end function

sub init()
    m.title = m.top.findNode("title")
    m.count = m.top.findNode("count")
    m.grid = m.top.findNode("grid")
    m.status = m.top.findNode("status")

    m.content = CreateObject("roSGNode", "ContentNode")
    m.grid.content = m.content
    m.buckets = []
    m.nextBucket = 0
    m.loading = false

    m.grid.observeField("itemFocused", "onItemFocused")
    m.grid.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.grid.setFocus(true)
end sub

sub onAlbumSet()
    album = m.top.album
    m.title.text = album.title
    m.count.text = formatItemCount(album.assetCount)
    m.query = "albumId=" + album.albumId + "&order=" + album.order
    m.status.text = "Loading..."
    m.task = startApiRequest(currentSettings(), "GET", "/api/timeline/buckets?" + m.query, "onBuckets")
end sub

sub onBuckets(event as object)
    resp = event.getData()
    m.task = invalid
    if not resp.ok
        m.status.text = describeApiError(resp)
        return
    end if
    m.buckets = resp.data
    if m.buckets.Count() = 0
        m.status.text = "This album is empty."
        return
    end if
    loadNextBucket()
end sub

sub loadNextBucket()
    if m.loading or m.nextBucket >= m.buckets.Count() then return
    m.loading = true
    bucket = m.buckets[m.nextBucket].timeBucket
    path = "/api/timeline/bucket?" + m.query + "&timeBucket=" + escapeQueryValue(bucket)
    m.task = startApiRequest(currentSettings(), "GET", path, "onBucket")
end sub

sub onBucket(event as object)
    resp = event.getData()
    m.task = invalid
    m.loading = false
    if not resp.ok
        ' Leave nextBucket alone so moving focus retries this month.
        if m.content.getChildCount() = 0 then m.status.text = describeApiError(resp)
        logDebug("bucket load failed: " + resp.status.ToStr())
        return
    end if

    m.nextBucket = m.nextBucket + 1
    appendAssets(resp.data)
    m.status.text = ""
    ' Small months: keep going until there's at least a couple of screens' worth.
    if m.content.getChildCount() < loadAheadItems() then loadNextBucket()
end sub

' Bucket responses are column arrays: id[], isImage[], duration[], ...
sub appendAssets(data as object)
    ids = data.id
    items = []
    for i = 0 to ids.Count() - 1
        durationMs = data.duration[i]
        if durationMs = invalid then durationMs = 0
        node = CreateObject("roSGNode", "ContentNode")
        node.update({
            assetId: ids[i]
            isVideo: not data.isImage[i]
            durationMs: durationMs
            thumbUrl: thumbnailUrl(ids[i], "thumbnail")
        }, true)
        items.Push(node)
    end for
    m.content.appendChildren(items)
    logDebug("album items loaded: " + m.content.getChildCount().ToStr())
end sub

sub onItemFocused()
    remaining = m.content.getChildCount() - m.grid.itemFocused
    if remaining <= loadAheadItems() then loadNextBucket()
end sub

sub onItemSelected()
    ' Phase 3: open PhotoViewer / Phase 4: VideoPlayer.
    item = m.content.getChild(m.grid.itemSelected)
    logDebug("selected " + item.assetId)
end sub
