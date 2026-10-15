' Space kept clear at the top and bottom of the rail.
function railPadding() as integer
    return 16
end function

' Year labels closer together than this are skipped (the mark and cursor still reach them).
function minLabelGap() as integer
    return 30
end function

sub init()
    m.line = m.top.findNode("line")
    m.labels = m.top.findNode("labels")
    m.marker = m.top.findNode("marker")
    m.cursorGroup = m.top.findNode("cursorGroup")
    m.bubble = m.top.findNode("bubble")
    m.bubbleText = m.top.findNode("bubbleText")
    m.hint = m.top.findNode("hint")
    m.months = []
    m.ys = []           ' y of each month on the rail
    m.cursorIndex = 0
    ' A little smaller than SmallestSystemFont so "2026" fits in the 80px margin.
    m.labelFont = CreateObject("roSGNode", "Font")
    m.labelFont.uri = "font:SystemFontFile"
    m.labelFont.size = 20
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

' Months are spaced by their photo counts, like the Immich web app's timeline.
sub onMonthsSet()
    m.months = m.top.months
    if m.months = invalid then m.months = []
    m.labels.removeChildrenIndex(m.labels.getChildCount(), 0)
    m.ys = []
    height = m.top.railHeight
    m.line.height = height
    m.hint.translation = [88, height - 44]
    if m.months.Count() = 0 then return

    total = 0
    for each month in m.months
        total = total + month.count
    end for
    if total = 0 then total = 1
    usable = height - 2 * railPadding()
    seen = 0
    lastLabelY = -1000
    for i = 0 to m.months.Count() - 1
        y = railPadding() + Int(usable * seen / total)
        m.ys.Push(y)
        seen = seen + m.months[i].count
        year = Left(m.months[i].timeBucket, 4)
        newYear = (i = 0) or (year <> Left(m.months[i - 1].timeBucket, 4))
        if newYear and y - lastLabelY >= minLabelGap()
            addYearLabel(year, y)
            lastLabelY = y
        end if
    end for
    updateMarker()
end sub

sub addYearLabel(year as string, y as integer)
    label = m.labels.createChild("Label")
    label.translation = [0, y - 14]
    label.width = 60
    label.height = 28
    label.horizAlign = "right"
    label.vertAlign = "center"
    label.font = m.labelFont
    label.color = "0x80888FFF"
    label.text = year
end sub

sub updateMarker()
    index = m.top.current
    m.marker.visible = (index >= 0 and index < m.ys.Count())
    if m.marker.visible then m.marker.translation = [60, m.ys[index] - 2]
end sub

' ---- Focused: the cursor ----

sub onFocusChanged()
    focused = m.top.hasFocus()
    m.cursorGroup.visible = focused
    m.hint.visible = focused
    if focused then moveCursor(m.cursorIndex)
end sub

sub onCursorSet()
    m.cursorIndex = m.top.cursor
    if m.top.hasFocus() then moveCursor(m.cursorIndex)
end sub

sub moveCursor(index as integer)
    if m.ys.Count() = 0 then return
    if index < 0 then index = 0
    if index > m.ys.Count() - 1 then index = m.ys.Count() - 1
    m.cursorIndex = index
    m.cursorGroup.translation = [0, m.ys[index]]
    m.bubbleText.text = formatMonthYear(m.months[index].timeBucket)
    m.bubble.width = m.bubbleText.boundingRect().width + 44
end sub

' The first month (in list order) of the next year down (+1) or up (-1) the rail, so a year
' jump always lands on the top of that year.
function yearStep(direction as integer) as integer
    i = m.cursorIndex
    year = yearAt(i)
    while i + direction >= 0 and i + direction < m.months.Count() and yearAt(i + direction) = year
        i = i + direction
    end while
    if i + direction < 0 or i + direction >= m.months.Count() then return i
    i = i + direction
    if direction < 0
        target = yearAt(i)
        while i - 1 >= 0 and yearAt(i - 1) = target
            i = i - 1
        end while
    end if
    return i
end function

function yearAt(index as integer) as string
    return Left(m.months[index].timeBucket, 4)
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return true
    if m.months.Count() = 0
        m.top.closed = true
    else if key = "down"
        moveCursor(m.cursorIndex + 1)
    else if key = "up"
        moveCursor(m.cursorIndex - 1)
    else if key = "fastforward"
        moveCursor(yearStep(1))
    else if key = "rewind"
        moveCursor(yearStep(-1))
    else if key = "OK"
        m.top.chosen = m.cursorIndex
    else if key = "right" or key = "back"
        m.top.closed = true
    else
        return false
    end if
    return true
end function
