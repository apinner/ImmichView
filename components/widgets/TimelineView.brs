' Loads more when focus gets within this many items of the end of what's loaded.
function loadAheadItems() as integer
    return 48
end function

' Smart search ranks the whole library; beyond this the results stop being relevant.
function searchResultLimit() as integer
    return 500
end function

function searchPageSize() as integer
    return 100
end function

' The first search after the server has been idle loads its model and can take ~1 minute.
function searchTimeoutMs() as integer
    return 90000
end function

sub init()
    m.grid = m.top.findNode("grid")
    m.status = m.top.findNode("status")
    m.slowTimer = m.top.findNode("slowTimer")
    m.slowTimer.observeField("fire", "onSlowTimer")
    m.mode = ""
    m.task = invalid
    resetData()

    m.grid.observeField("itemFocused", "onItemFocused")
    m.grid.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.grid.setFocus(true)
end sub

sub resetData()
    m.assets = []
    m.buckets = []
    m.nextBucket = 0
    m.nextPage = 1
    m.loading = false
    m.top.assetCount = 0
    m.top.hasMore = false
end sub

' True if this response belongs to the request in flight (not one superseded by a new query).
function isCurrent(event as object) as boolean
    return m.task <> invalid and event.getRoSGNode().isSameNode(m.task)
end function

' ---- Timeline (buckets) ----

sub onQueryChanged()
    m.mode = "timeline"
    m.status.text = "Loading..."
    m.task = startApiRequest(currentSettings(), "GET", "/api/timeline/buckets?" + m.top.query, "onBuckets")
end sub

sub onBuckets(event as object)
    if not isCurrent(event) then return
    resp = event.getData()
    m.task = invalid
    if not resp.ok
        m.status.text = describeApiError(resp)
        m.top.loaded = true
        return
    end if
    m.buckets = resp.data
    total = 0
    for each bucket in m.buckets
        total = total + bucket.count
    end for
    m.top.totalCount = total
    m.top.hasMore = m.buckets.Count() > 0
    if m.buckets.Count() = 0
        m.status.text = m.top.emptyText
        m.top.loaded = true
        return
    end if
    loadMore()
end sub

sub loadNextBucket()
    if m.loading or m.nextBucket >= m.buckets.Count() then return
    m.loading = true
    bucket = m.buckets[m.nextBucket].timeBucket
    path = "/api/timeline/bucket?" + m.top.query + "&timeBucket=" + escapeQueryValue(bucket)
    m.task = startApiRequest(currentSettings(), "GET", path, "onBucket")
end sub

sub onBucket(event as object)
    if not isCurrent(event) then return
    resp = event.getData()
    m.task = invalid
    m.loading = false
    if not resp.ok
        ' Leave nextBucket alone so moving focus retries this month.
        if m.assets.Count() = 0 then m.status.text = describeApiError(resp)
        m.top.loaded = true
        logDebug("bucket load failed: " + resp.status.ToStr())
        return
    end if

    title = formatMonthYear(m.buckets[m.nextBucket].timeBucket)
    m.nextBucket = m.nextBucket + 1
    m.top.hasMore = m.nextBucket < m.buckets.Count()
    appendBucket(title, resp.data)
    m.status.text = ""
    ' Small months: keep going until there's at least a couple of screens' worth.
    if m.assets.Count() < loadAheadItems() then loadMore()
end sub

' Bucket responses are column arrays: id[], isImage[], duration[], ratio[], ...
sub appendBucket(title as string, data as object)
    ids = data.id
    items = []
    for i = 0 to ids.Count() - 1
        durationMs = data.duration[i]
        if durationMs = invalid then durationMs = 0
        ratio = data.ratio[i]
        if ratio = invalid then ratio = 1.0
        items.Push({ assetId: ids[i], ratio: ratio, isVideo: not data.isImage[i], durationMs: durationMs })
    end for
    appendItems({ title: title, items: items })
end sub

' ---- Smart search ----

sub onSearchTextChanged()
    m.mode = "search"
    m.grid.clear = true
    resetData()
    m.top.totalCount = -1
    if m.top.searchText = ""
        m.task = invalid
        m.status.text = ""
        return
    end if
    m.status.text = "Searching..."
    m.slowTimer.control = "start"
    loadMore()
end sub

sub onSlowTimer()
    if m.mode = "search" and m.loading and m.assets.Count() = 0
        m.status.text = "Still searching... the first search after a while can take up to a minute while the server gets ready."
    end if
end sub

sub loadNextSearchPage()
    if m.loading or m.nextPage = invalid then return
    m.loading = true
    body = { query: m.top.searchText, page: m.nextPage, size: searchPageSize() }
    m.task = startApiRequest(currentSettings(), "POST", "/api/search/smart", "onSearchPage", body, searchTimeoutMs())
end sub

sub onSearchPage(event as object)
    if not isCurrent(event) then return
    resp = event.getData()
    m.task = invalid
    m.loading = false
    if not resp.ok
        if m.assets.Count() = 0 then m.status.text = describeApiError(resp)
        m.top.loaded = true
        logDebug("search page failed: " + resp.status.ToStr())
        return
    end if

    result = resp.data.assets
    firstPage = (m.assets.Count() = 0)
    m.nextPage = invalid
    if result.nextPage <> invalid and m.assets.Count() + result.items.Count() < searchResultLimit()
        m.nextPage = result.nextPage.ToInt()
    end if
    m.top.hasMore = (m.nextPage <> invalid)

    items = []
    for each asset in result.items
        items.Push(searchItem(asset))
    end for
    if items.Count() = 0 and firstPage
        m.status.text = "No results for " + Chr(34) + m.top.searchText + Chr(34) + "."
        return
    end if
    m.status.text = ""
    appendItems({ title: "", items: items, continues: not firstPage })
end sub

function searchItem(asset as object) as object
    ratio = 1.0
    if asset.width <> invalid and asset.height <> invalid and asset.height > 0 then ratio = asset.width / asset.height
    durationMs = asset.duration
    if durationMs = invalid then durationMs = 0
    return { assetId: asset.id, ratio: ratio, isVideo: asset.type = "VIDEO", durationMs: durationMs }
end function

' ---- Shared ----

sub loadMore()
    if m.mode = "search"
        loadNextSearchPage()
    else
        loadNextBucket()
    end if
end sub

sub appendItems(group as object)
    for each item in group.items
        m.assets.Push(item)
    end for
    m.grid.appendGroup = group
    m.top.assetCount = m.assets.Count()
    m.top.loaded = true
    logDebug("items loaded: " + m.assets.Count().ToStr())
end sub

sub onItemFocused()
    remaining = m.assets.Count() - m.grid.itemFocused
    if remaining <= loadAheadItems() then loadMore()
end sub

sub onItemSelected()
    index = m.grid.itemSelected
    m.top.itemSelected = { index: index, asset: m.assets[index] }
end sub

' ---- PhotoViewer access (callFunc) ----

function getAsset(index as integer) as dynamic
    if index < 0 or index >= m.assets.Count() then return invalid
    return m.assets[index]
end function

function requestMore() as boolean
    loadMore()
    return true
end function
