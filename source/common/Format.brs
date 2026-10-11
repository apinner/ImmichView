' Small display formatting helpers.

function formatDuration(ms as dynamic) as string
    if ms = invalid or ms <= 0 then return ""
    total = Int(ms / 1000)
    hours = Int(total / 3600)
    mins = Int((total MOD 3600) / 60)
    secs = total MOD 60
    text = padTwo(secs)
    if hours > 0
        return hours.ToStr() + ":" + padTwo(mins) + ":" + text
    end if
    return mins.ToStr() + ":" + text
end function

function padTwo(n as integer) as string
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

function monthNames() as object
    return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
end function

' "2020-11-01" (timeline bucket) -> "November 2020"
function formatMonthYear(isoDate as string) as string
    month = Mid(isoDate, 6, 2).ToInt()
    if month < 1 or month > 12 then return isoDate
    return monthNames()[month - 1] + " " + Left(isoDate, 4)
end function

' Immich localDateTime (local time, written with a Z) -> "Monday 28 September 2026, 12:44"
function formatPhotoDate(localDateTime as dynamic) as string
    if localDateTime = invalid or localDateTime = "" then return ""
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(localDateTime)
    text = dt.GetWeekday() + " " + dt.GetDayOfMonth().ToStr() + " " + monthNames()[dt.GetMonth() - 1]
    text = text + " " + dt.GetYear().ToStr() + ", " + padTwo(dt.GetHours()) + ":" + padTwo(dt.GetMinutes())
    return text
end function

' Immich localDateTime -> "28 September 2026"
function formatShortDate(localDateTime as dynamic) as string
    if localDateTime = invalid or localDateTime = "" then return ""
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(localDateTime)
    return dt.GetDayOfMonth().ToStr() + " " + monthNames()[dt.GetMonth() - 1] + " " + dt.GetYear().ToStr()
end function

' 1.9 -> "1.9", 5.0 -> "5"
function formatOneDecimal(value as dynamic) as string
    tenths = Int(value * 10 + 0.5)
    whole = Int(tenths / 10)
    if tenths MOD 10 = 0 then return whole.ToStr()
    return whole.ToStr() + "." + (tenths MOD 10).ToStr()
end function

' Joins the non-empty strings in parts.
function joinNonEmpty(parts as object, separator as string) as string
    text = ""
    for each part in parts
        if part <> invalid and part <> ""
            if text <> "" then text = text + separator
            text = text + part
        end if
    end for
    return text
end function

function formatItemCount(count as dynamic) as string
    if count = invalid then return ""
    if count = 1 then return "1 item"
    return count.ToStr() + " items"
end function

' The current local time, "15:07" or "3:07 PM" (twelveHour).
function formatClock(twelveHour as boolean) as string
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    hours = dt.GetHours()
    minutes = padTwo(dt.GetMinutes())
    if not twelveHour then return padTwo(hours) + ":" + minutes
    suffix = " AM"
    if hours >= 12 then suffix = " PM"
    hours = hours MOD 12
    if hours = 0 then hours = 12
    return hours.ToStr() + ":" + minutes + suffix
end function
