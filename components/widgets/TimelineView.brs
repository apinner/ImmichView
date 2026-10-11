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
    m.grid.observeField("exitedTop", "onGridExitedTop")
    m.grid.observeField("exitedLeft", "onGridExitedLeft")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.global.observeField("mediaFilter", "onFilterChanged")
end sub

' ---- Photos / videos filter (m.global.mediaFilter) ----
' The timeline API can't filter by type, so bucket items are filtered here; search asks the server.

function matchesFilter(isVideo as boolean) as boolean
    filter = m.global.mediaFilter
    if filter = "photos" then return not isVideo
    if filter = "videos" then return isVideo
    return true
end function

function emptyMessage() as string
    if m.global.mediaFilter = "photos" then return "No photos here."
    if m.global.mediaFilter = "videos" then return "No videos here."
    return m.top.emptyText
end function

sub onFilterChanged()
    if m.mode = "timeline" and m.top.query <> ""
        m.grid.clear = true
        resetData()
        onQueryChanged()
    else if m.mode = "search" and m.top.searchText <> ""
        onSearchTextChanged()
    end if
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.grid.setFocus(true)
end sub

sub resetData()
    m.assets = []
    m.buckets = []
    resetLoadedMonths(0)
    m.nextPage = 1
    m.top.hasMore = false
end sub

' Forgets the loaded photos; the timeline will load from month index first onwards.
sub resetLoadedMonths(first as integer)
    m.assets = []
    m.firstBucket = first   ' earliest loaded bucket index (newer months load above it)
    m.nextBucket = first    ' next bucket to load below
    m.monthStarts = []      ' { start, bucket }: first asset index of each loaded month
    m.task = invalid
    m.prevTask = invalid
    m.loading = false
    m.loadingPrev = false
    m.top.assetCount = 0
end sub

' True if this response belongs to the request in flight (not one superseded by a new query).
function isCurrent(event as object) as boolean
    return m.task <> invalid and event.getRoSGNode().isSameNode(m.task)
end function

' ---- Timeline (buckets) ----

sub onQueryChanged()
    m.mode = "timeline"
    m.grid.exitLeft = true
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
    months = []
    for each bucket in m.buckets
        total = total + bucket.count
        months.Push({ timeBucket: bucket.timeBucket, count: bucket.count })
    end for
    m.top.months = months
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
    m.task = startApiRequest(currentSettings(), "GET", bucketPath(m.nextBucket), "onBucket")
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

    bucketIndex = m.nextBucket
    m.nextBucket = m.nextBucket + 1
    m.top.hasMore = m.nextBucket < m.buckets.Count()
    items = bucketItems(resp.data)
    added = items.Count()
    if added > 0
        m.monthStarts.Push({ start: m.assets.Count(), bucket: bucketIndex })
        appendItems({ title: formatMonthYear(m.buckets[bucketIndex].timeBucket), items: items })
    end if
    if m.assets.Count() > 0 then m.status.text = ""
    if added = 0 and not m.top.hasMore and m.assets.Count() = 0
        ' The filter matched nothing in any month.
        m.status.text = emptyMessage()
        m.top.loaded = true
        return
    end if
    ' Small months (or months with nothing matching the filter): keep going until
    ' there's at least a couple of screens' worth.
    if m.assets.Count() < loadAheadItems() or added = 0 then loadMore()
end sub

' Bucket responses are column arrays: id[], isImage[], duration[], ratio[], ...
' Returns the items that match the filter.
function bucketItems(data as object) as object
    ids = data.id
    items = []
    for i = 0 to ids.Count() - 1
        isVideo = not data.isImage[i]
        if matchesFilter(isVideo)
            durationMs = data.duration[i]
            if durationMs = invalid then durationMs = 0
            ratio = data.ratio[i]
            if ratio = invalid then ratio = 1.0
            items.Push({ assetId: ids[i], ratio: ratio, isVideo: isVideo, durationMs: durationMs })
        end if
    end for
    return items
end function

' ---- Months: jumping to one, and loading newer months above ----

function bucketPath(index as integer) as string
    return "/api/timeline/bucket?" + m.top.query + "&timeBucket=" + escapeQueryValue(m.buckets[index].timeBucket)
end function

' Index of the month the photo at assetIndex belongs to.
function monthAt(assetIndex as integer) as integer
    month = m.firstBucket
    for each entry in m.monthStarts
        if entry.start > assetIndex then exit for
        month = entry.bucket
    end for
    return month
end function

' Shows the given month: straight there if it's loaded, else the timeline starts again at it
' (loading every month in between would take far too long on a big library).
function jumpToMonth(index as integer) as boolean
    if m.mode <> "timeline" or index < 0 or index >= m.buckets.Count() then return false
    for each entry in m.monthStarts
        if entry.bucket = index
            m.grid.jumpToItem = entry.start
            return true
        end if
    end for
    m.grid.clear = true
    resetLoadedMonths(index)
    m.top.hasMore = true
    m.status.text = "Loading..."
    loadMore()
    return true
end function

sub onGridExitedLeft()
    if m.mode <> "timeline" or m.buckets.Count() < 2 then return
    m.top.monthIndex = monthAt(m.grid.itemFocused)
    m.top.jumpRequested = true
end sub

' Up on the first row: load the next newer month if there is one, else let the screen move focus.
sub onGridExitedTop()
    if m.mode = "timeline" and m.firstBucket > 0
        loadPrevious()
    else
        m.top.exitedTop = true
    end if
end sub

sub loadPrevious()
    if m.mode <> "timeline" or m.loadingPrev or m.firstBucket <= 0 then return
    m.loadingPrev = true
    m.prevTask = startApiRequest(currentSettings(), "GET", bucketPath(m.firstBucket - 1), "onPreviousBucket")
end sub

sub onPreviousBucket(event as object)
    if m.prevTask = invalid or not event.getRoSGNode().isSameNode(m.prevTask) then return
    resp = event.getData()
    m.prevTask = invalid
    m.loadingPrev = false
    if not resp.ok
        logDebug("previous bucket load failed: " + resp.status.ToStr())
        return
    end if
    m.firstBucket = m.firstBucket - 1
    items = bucketItems(resp.data)
    if items.Count() = 0
        loadPrevious()  ' nothing in that month matches the filter
        return
    end if

    added = items.Count()
    for each entry in m.monthStarts
        entry.start = entry.start + added
    end for
    m.monthStarts.Unshift({ start: 0, bucket: m.firstBucket })
    assets = []
    assets.Append(items)
    assets.Append(m.assets)
    m.assets = assets
    m.top.assetCount = m.assets.Count()
    m.grid.prependGroup = { title: formatMonthYear(m.buckets[m.firstBucket].timeBucket), items: items }
    logDebug("items loaded above: " + added.ToStr())
end sub

' ---- Smart search ----

sub onSearchTextChanged()
    m.mode = "search"
    m.grid.exitLeft = false
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
    if m.global.mediaFilter = "photos" then body.type = "IMAGE"
    if m.global.mediaFilter = "videos" then body.type = "VIDEO"
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
    if m.mode = "timeline" and m.firstBucket > 0 and m.grid.itemFocused < loadAheadItems() then loadPrevious()
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
