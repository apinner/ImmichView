' Space kept clear at the top and bottom of the rail.
function railPadding() as integer
    return 16
end function

' Year labels closer together than this are skipped (the cursor still reaches those years).
function minLabelGap() as integer
    return 30
end function

' Holding a key: pause before repeating, then the repeat interval, faster after a while.
function holdDelay() as float
    return 0.4
end function

function holdInterval(steps as integer) as float
    if steps > 12 then return 0.04
    return 0.09
end function

sub init()
    m.line = m.top.findNode("line")
    m.marker = m.top.findNode("marker")
    m.labels = m.top.findNode("labels")
    m.cursorGroup = m.top.findNode("cursorGroup")
    m.bubble = m.top.findNode("bubble")
    m.bubbleText = m.top.findNode("bubbleText")
    m.hint = m.top.findNode("hint")
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "onHoldTimer")
    m.months = []
    m.ys = []           ' y of each month on the rail
    m.yearLabels = []   ' { first, node }: each label shown and the month it starts at
    m.cursorIndex = 0
    m.holdKey = ""
    m.holdSteps = 0
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
    m.yearLabels = []
    height = m.top.railHeight
    m.line.height = height
    m.hint.translation = [76, height - 44]
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
        year = yearAt(i)
        newYear = (i = 0) or (year <> yearAt(i - 1))
        if newYear and y - lastLabelY >= minLabelGap()
            m.yearLabels.Push({ first: i, node: addYearLabel(year, y) })
            lastLabelY = y
        end if
    end for
    updateCurrentYear()
end sub

function addYearLabel(year as string, y as integer) as object
    label = m.labels.createChild("Label")
    label.translation = [0, y - 14]
    label.width = 60
    label.height = 28
    label.horizAlign = "right"
    label.vertAlign = "center"
    label.font = m.labelFont
    label.color = yearColor(false)
    label.text = year
    return label
end function

function yearColor(isCurrent as boolean) as string
    if isCurrent then return "0xFFFFFFFF"
    return "0x6A6F7AFF"
end function

' The year on screen shows brighter: its own label, or the nearest shown label above it
' when its label was skipped for space.
sub updateCurrentYear()
    index = m.top.current
    m.marker.visible = (index >= 0 and index < m.ys.Count())
    if m.marker.visible then m.marker.translation = [0, m.ys[index] - 1]
    currentLabel = invalid
    if index >= 0 and index < m.months.Count()
        for each entry in m.yearLabels
            if entry.first <= index then currentLabel = entry.node
        end for
    end if
    for each entry in m.yearLabels
        entry.node.color = yearColor(currentLabel <> invalid and entry.node.isSameNode(currentLabel))
    end for
end sub

' ---- Focused: the cursor ----

sub onFocusChanged()
    focused = m.top.hasFocus()
    m.cursorGroup.visible = focused
    m.hint.visible = focused
    if focused then moveCursor(m.cursorIndex) else stopHold()
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

' One step for the held (or pressed) key.
sub stepFor(key as string)
    if key = "down"
        moveCursor(m.cursorIndex + 1)
    else if key = "up"
        moveCursor(m.cursorIndex - 1)
    else if key = "fastforward"
        moveCursor(yearStep(1))
    else if key = "rewind"
        moveCursor(yearStep(-1))
    end if
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

' ---- Holding a key ----

sub startHold(key as string)
    m.holdKey = key
    m.holdSteps = 0
    m.holdTimer.control = "stop"
    m.holdTimer.duration = holdDelay()
    m.holdTimer.control = "start"
end sub

sub stopHold()
    m.holdKey = ""
    m.holdTimer.control = "stop"
end sub

sub onHoldTimer()
    if m.holdKey = "" then return
    stepFor(m.holdKey)
    m.holdSteps = m.holdSteps + 1
    interval = holdInterval(m.holdSteps)
    ' Years go more slowly, so each one can be read.
    if m.holdKey = "fastforward" or m.holdKey = "rewind" then interval = 0.35
    if m.holdTimer.duration <> interval
        m.holdTimer.control = "stop"
        m.holdTimer.duration = interval
        m.holdTimer.control = "start"
    end if
end sub

function isStepKey(key as string) as boolean
    return key = "up" or key = "down" or key = "fastforward" or key = "rewind"
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press
        if key = m.holdKey then stopHold()
        return true
    end if
    if m.months.Count() = 0
        m.top.closed = true
    else if isStepKey(key)
        stepFor(key)
        startHold(key)
    else if key = "OK"
        stopHold()
        m.top.chosen = m.cursorIndex
    else if key = "right" or key = "back"
        stopHold()
        m.top.closed = true
    else
        return false
    end if
    return true
end function
