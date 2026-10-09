' Loads more when focus gets within this many items of the end of what's loaded.
function loadAheadItems() as integer
    return 48
end function

sub init()
    m.grid = m.top.findNode("grid")
    m.status = m.top.findNode("status")

    m.assets = []
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

sub onQueryChanged()
    m.status.text = "Loading..."
    m.task = startApiRequest(currentSettings(), "GET", "/api/timeline/buckets?" + m.top.query, "onBuckets")
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
        m.status.text = m.top.emptyText
        return
    end if
    loadNextBucket()
end sub

sub loadNextBucket()
    if m.loading or m.nextBucket >= m.buckets.Count() then return
    m.loading = true
    bucket = m.buckets[m.nextBucket].timeBucket
    path = "/api/timeline/bucket?" + m.top.query + "&timeBucket=" + escapeQueryValue(bucket)
    m.task = startApiRequest(currentSettings(), "GET", path, "onBucket")
end sub

sub onBucket(event as object)
    resp = event.getData()
    m.task = invalid
    m.loading = false
    if not resp.ok
        ' Leave nextBucket alone so moving focus retries this month.
        if m.assets.Count() = 0 then m.status.text = describeApiError(resp)
        logDebug("bucket load failed: " + resp.status.ToStr())
        return
    end if

    title = formatMonthYear(m.buckets[m.nextBucket].timeBucket)
    m.nextBucket = m.nextBucket + 1
    appendAssets(title, resp.data)
    m.status.text = ""
    ' Small months: keep going until there's at least a couple of screens' worth.
    if m.assets.Count() < loadAheadItems() then loadNextBucket()
end sub

' Bucket responses are column arrays: id[], isImage[], duration[], ratio[], ...
sub appendAssets(title as string, data as object)
    ids = data.id
    items = []
    for i = 0 to ids.Count() - 1
        durationMs = data.duration[i]
        if durationMs = invalid then durationMs = 0
        ratio = data.ratio[i]
        if ratio = invalid then ratio = 1.0
        asset = { assetId: ids[i], ratio: ratio, isVideo: not data.isImage[i], durationMs: durationMs }
        items.Push(asset)
        m.assets.Push(asset)
    end for
    m.grid.appendGroup = { title: title, items: items }
    logDebug("timeline items loaded: " + m.assets.Count().ToStr())
end sub

sub onItemFocused()
    remaining = m.assets.Count() - m.grid.itemFocused
    if remaining <= loadAheadItems() then loadNextBucket()
end sub

sub onItemSelected()
    index = m.grid.itemSelected
    m.top.itemSelected = { index: index, asset: m.assets[index] }
end sub
