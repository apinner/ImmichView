' Height reserved above each group for its header label.
function headerHeight() as integer
    return 64
end function

sub init()
    m.viewport = m.top.findNode("viewport")
    m.content = m.top.findNode("content")
    m.rowsGroup = m.top.findNode("rows")
    m.focusFrame = m.top.findNode("focusFrame")
    m.anim = m.top.findNode("scrollAnim")
    m.interp = m.top.findNode("scrollInterp")
    m.agent = createAuthAgent()
    resetState()
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub resetState()
    m.items = []        ' every appended item
    m.rows = []         ' { start, count, top, height, xs[], widths[] }
    m.headers = []      ' { top, title }
    m.itemRow = []      ' item index -> row index
    m.contentHeight = 0
    m.nodes = {}        ' "r<row>" / "h<header>" -> node currently on screen
    m.focus = -1
    m.stickyX = invalid ' remembered column centre for repeated up/down
    m.scrollY = 0
end sub

sub onClear()
    m.anim.control = "stop"
    m.rowsGroup.removeChildrenIndex(m.rowsGroup.getChildCount(), 0)
    m.content.translation = [0, 0]
    m.focusFrame.visible = false
    resetState()
end sub

sub onFocusChanged()
    m.focusFrame.visible = m.top.hasFocus() and m.focus >= 0
end sub

' ---- Layout ----

sub onAppendGroup()
    group = m.top.appendGroup
    if group.items = invalid or group.items.Count() = 0 then return

    start = m.items.Count()
    if group.continues <> invalid and group.continues and m.rows.Count() > 0
        start = reopenLastRow()
    else if group.title <> invalid and group.title <> ""
        if m.rows.Count() > 0 then m.contentHeight = m.contentHeight + 24
        m.headers.Push({ top: m.contentHeight, title: group.title })
        m.contentHeight = m.contentHeight + headerHeight()
    end if

    for each item in group.items
        m.items.Push(item)
    end for
    layoutRows(start, m.items.Count())

    if m.focus < 0
        setFocusIndex(0, false)
    else if m.focus >= start
        setFocusIndex(m.focus, false)  ' its row was laid out again
    else
        refreshVisibleNodes()
    end if
end sub

' Takes the last (partial) row back out so new items can fill it. Returns its first item.
function reopenLastRow() as integer
    row = m.rows.Pop()
    for i = 1 to row.count
        m.itemRow.Pop()
    end for
    m.contentHeight = row.top
    key = "r" + m.rows.Count().ToStr()
    if m.nodes.DoesExist(key)
        m.rowsGroup.removeChild(m.nodes[key])
        m.nodes.Delete(key)
    end if
    return row.start
end function

function itemAspect(item as object) as float
    ratio = item.ratio
    if ratio = invalid or ratio <= 0 then return 1.0
    if ratio < 0.5 then return 0.5
    if ratio > 3.0 then return 3.0
    return ratio
end function

' Packs items [first, last) into full-width rows; the group's final row keeps its natural size.
sub layoutRows(first as integer, last as integer)
    width = m.top.gridWidth
    height = m.top.targetRowHeight
    gap = m.top.spacing

    rowStart = first
    sumWidth = 0.0
    for i = first to last - 1
        w = itemAspect(m.items[i]) * height
        count = i - rowStart + 1
        if count > 1 and sumWidth + w + gap * (count - 1) >= width
            ' Row is full: keep this item in it only if that distorts the row height less.
            scaleWith = (width - gap * (count - 1)) / (sumWidth + w)
            scaleWithout = (width - gap * (count - 2)) / sumWidth
            if Abs(Log(scaleWith)) <= Abs(Log(scaleWithout))
                addRow(rowStart, count, scaleWith)
                rowStart = i + 1
                sumWidth = 0.0
            else
                addRow(rowStart, count - 1, scaleWithout)
                rowStart = i
                sumWidth = w
            end if
        else
            sumWidth = sumWidth + w
        end if
    end for
    if rowStart < last then addRow(rowStart, last - rowStart, 1.0)
end sub

sub addRow(start as integer, count as integer, scale as float)
    rowHeight = m.top.targetRowHeight * scale
    gap = m.top.spacing
    rowIndex = m.rows.Count()
    xs = []
    widths = []
    x = 0.0
    for j = 0 to count - 1
        w = itemAspect(m.items[start + j]) * rowHeight
        left = Int(x + 0.5)
        right = Int(x + w + 0.5)
        xs.Push(left)
        widths.Push(right - left)
        m.itemRow.Push(rowIndex)
        x = x + w + gap
    end for
    m.rows.Push({ start: start, count: count, top: m.contentHeight, height: Int(rowHeight + 0.5), xs: xs, widths: widths })
    m.contentHeight = m.contentHeight + Int(rowHeight + 0.5) + gap
end sub

' ---- Rendering (only rows and headers near the viewport) ----

sub refreshVisibleNodes()
    viewHeight = m.top.viewHeight
    m.viewport.clippingRect = [-8, -8, m.top.gridWidth + 16, viewHeight + 16]
    rangeTop = m.scrollY - viewHeight * 0.5
    rangeBottom = m.scrollY + viewHeight * 1.5

    keep = {}
    r = firstRowEndingBelow(rangeTop)
    while r < m.rows.Count() and m.rows[r].top <= rangeBottom
        key = "r" + r.ToStr()
        keep[key] = true
        if not m.nodes.DoesExist(key) then m.nodes[key] = createRowNode(r)
        r = r + 1
    end while
    for h = 0 to m.headers.Count() - 1
        top = m.headers[h].top
        if top + headerHeight() >= rangeTop and top <= rangeBottom
            key = "h" + h.ToStr()
            keep[key] = true
            if not m.nodes.DoesExist(key) then m.nodes[key] = createHeaderNode(h)
        end if
    end for

    for each key in m.nodes.Keys()
        if not keep.DoesExist(key)
            m.rowsGroup.removeChild(m.nodes[key])
            m.nodes.Delete(key)
        end if
    end for
end sub

' Binary search for the first row whose bottom edge is below y.
function firstRowEndingBelow(y as float) as integer
    lo = 0
    hi = m.rows.Count()
    while lo < hi
        mid = Int((lo + hi) / 2)
        row = m.rows[mid]
        if row.top + row.height < y
            lo = mid + 1
        else
            hi = mid
        end if
    end while
    return lo
end function

function createRowNode(rowIndex as integer) as object
    row = m.rows[rowIndex]
    group = m.rowsGroup.createChild("Group")
    group.translation = [0, row.top]
    for j = 0 to row.count - 1
        addTile(group, m.items[row.start + j], row.xs[j], row.widths[j], row.height)
    end for
    return group
end function

' Tiles are plain nodes sharing one auth agent: a component per tile (each loading the
' CA bundle for its own agent) was slow enough to trip the render thread watchdog.
sub addTile(parent as object, asset as object, x as integer, w as integer, h as integer)
    placeholder = parent.createChild("Rectangle")
    placeholder.translation = [x, 0]
    placeholder.width = w
    placeholder.height = h
    placeholder.color = "0x2E2D3AFF"

    thumb = parent.createChild("Poster")
    thumb.setHttpAgent(m.agent)
    thumb.translation = [x, 0]
    thumb.width = w
    thumb.height = h
    thumb.loadWidth = w
    thumb.loadHeight = h
    thumb.loadDisplayMode = "scaleToZoom"
    thumb.uri = thumbnailUrl(asset.assetId, "thumbnail")

    if asset.isVideo then addVideoBadge(parent, x + 8, h - 44, asset.durationMs)
end sub

sub addVideoBadge(parent as object, x as integer, y as integer, durationMs as dynamic)
    badge = parent.createChild("Group")
    badge.translation = [x, y]
    background = badge.createChild("Rectangle")
    background.width = 104
    background.height = 36
    background.color = "0x000000B0"
    icon = badge.createChild("Poster")
    icon.uri = "pkg:/images/play.png"
    icon.width = 16
    icon.height = 16
    icon.translation = [10, 10]
    label = badge.createChild("Label")
    label.translation = [32, 0]
    label.width = 68
    label.height = 36
    label.vertAlign = "center"
    label.font = "font:SmallestSystemFont"
    label.color = "0xFFFFFFFF"
    label.text = formatDuration(durationMs)
end sub

function createHeaderNode(index as integer) as object
    header = m.rowsGroup.createChild("Label")
    header.translation = [0, m.headers[index].top]
    header.height = headerHeight() - 12
    header.vertAlign = "bottom"
    header.font = "font:MediumBoldSystemFont"
    header.color = "0xE0E4E8FF"
    header.text = m.headers[index].title
    return header
end function

' ---- Focus and scrolling ----

sub setFocusIndex(index as integer, animate as boolean)
    m.focus = index
    row = m.rows[m.itemRow[index]]
    col = index - row.start
    m.focusFrame.translation = [row.xs[col], row.top]
    m.focusFrame.width = row.widths[col]
    m.focusFrame.height = row.height
    m.focusFrame.visible = m.top.hasFocus()
    scrollToRow(row, animate)
    m.top.itemFocused = index
end sub

' Keeps the focused row on screen with room above it for a group header.
sub scrollToRow(row as object, animate as boolean)
    viewHeight = m.top.viewHeight
    margin = headerHeight() + 24
    target = m.scrollY
    if row.top + row.height + margin > target + viewHeight then target = row.top + row.height + margin - viewHeight
    if row.top - margin < target then target = row.top - margin
    if target < 0 then target = 0

    if target <> m.scrollY
        m.scrollY = target
        refreshVisibleNodes()
        if animate
            m.anim.control = "stop"
            m.interp.keyValue = [m.content.translation, [0, -target]]
            m.anim.control = "start"
        else
            m.content.translation = [0, -target]
        end if
    else
        refreshVisibleNodes()
    end if
end sub

sub onJumpToItem()
    index = m.top.jumpToItem
    if index < 0 or index >= m.items.Count() then return
    m.stickyX = invalid
    setFocusIndex(index, false)
end sub

function moveToItem(index as integer) as boolean
    if index < 0 or index >= m.items.Count() then return false
    m.stickyX = invalid
    setFocusIndex(index, true)
    return true
end function

' Moves focus delta rows up/down to the item nearest the same horizontal position.
function moveRows(delta as integer) as boolean
    current = m.itemRow[m.focus]
    target = current + delta
    if target < 0 then target = 0
    if target > m.rows.Count() - 1 then target = m.rows.Count() - 1
    if target = current
        if delta < 0 then m.top.exitedTop = true
        return true
    end if

    if m.stickyX = invalid
        row = m.rows[current]
        col = m.focus - row.start
        m.stickyX = row.xs[col] + row.widths[col] / 2
    end if

    newRow = m.rows[target]
    best = 0
    bestDistance = 100000
    for j = 0 to newRow.count - 1
        distance = Abs(newRow.xs[j] + newRow.widths[j] / 2 - m.stickyX)
        if distance < bestDistance
            best = j
            bestDistance = distance
        end if
    end for
    setFocusIndex(newRow.start + best, true)
    return true
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.focus < 0 then return false
    if key = "right"
        return moveToItem(m.focus + 1)
    else if key = "left"
        return moveToItem(m.focus - 1)
    else if key = "down"
        return moveRows(1)
    else if key = "up"
        return moveRows(-1)
    else if key = "fastforward"
        return moveRows(4)
    else if key = "rewind"
        return moveRows(-4)
    else if key = "OK"
        m.top.itemSelected = m.focus
        return true
    end if
    return false
end function
