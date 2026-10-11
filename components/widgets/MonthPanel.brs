sub init()
    m.years = m.top.findNode("years")
    m.monthList = m.top.findNode("monthList")
    m.yearGroups = []   ' { year, indexes[] }: month indexes in each year, in timeline order
    m.shownYear = -1

    m.years.observeField("itemFocused", "onYearFocused")
    m.years.observeField("itemSelected", "onYearSelected")
    m.monthList.observeField("itemSelected", "onMonthSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.findNode("slide").control = "start"
end sub

' Starts on the current month in the month list.
sub onFocusChanged()
    if m.top.hasFocus() then m.monthList.setFocus(true)
end sub

sub onMonthsSet()
    months = m.top.months
    m.months = months
    if months = invalid or months.Count() = 0 then return
    m.yearGroups = []
    currentYear = 0
    currentRow = 0
    for i = 0 to months.Count() - 1
        year = Left(months[i].timeBucket, 4)
        if m.yearGroups.Count() = 0 or m.yearGroups.Peek().year <> year
            m.yearGroups.Push({ year: year, indexes: [] })
        end if
        group = m.yearGroups.Peek()
        if i = m.top.current
            currentYear = m.yearGroups.Count() - 1
            currentRow = group.indexes.Count()
        end if
        group.indexes.Push(i)
    end for

    content = CreateObject("roSGNode", "ContentNode")
    for each group in m.yearGroups
        item = content.createChild("ContentNode")
        item.title = group.year
    end for
    m.years.content = content
    m.years.jumpToItem = currentYear
    showYear(currentYear)
    m.monthList.jumpToItem = currentRow
end sub

sub showYear(yearIndex as integer)
    if yearIndex = m.shownYear or yearIndex < 0 or yearIndex >= m.yearGroups.Count() then return
    m.shownYear = yearIndex
    names = monthNames()
    content = CreateObject("roSGNode", "ContentNode")
    for each index in m.yearGroups[yearIndex].indexes
        month = m.months[index]
        number = Mid(month.timeBucket, 6, 2).ToInt()
        title = month.timeBucket
        if number >= 1 and number <= 12 then title = names[number - 1]
        item = content.createChild("ContentNode")
        item.title = title + "   " + Chr(183) + "   " + month.count.ToStr()
    end for
    m.monthList.content = content
    m.monthList.jumpToItem = 0
end sub

' Moving through the years shows each year's months alongside.
sub onYearFocused()
    if m.years.hasFocus() then showYear(m.years.itemFocused)
end sub

' OK on a year jumps to its first month in the list.
sub onYearSelected()
    choose(m.yearGroups[m.years.itemSelected].indexes[0])
end sub

sub onMonthSelected()
    choose(m.yearGroups[m.shownYear].indexes[m.monthList.itemSelected])
end sub

sub choose(index as integer)
    m.top.chosen = index
    m.top.closed = true
end sub

' The panel keeps focus until closed.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return true
    if key = "back"
        m.top.closed = true
    else if key = "right" and m.years.hasFocus()
        showYear(m.years.itemFocused)
        m.monthList.setFocus(true)
    else if key = "left" and m.monthList.hasFocus()
        m.years.setFocus(true)
    end if
    return true
end function
