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

function formatItemCount(count as dynamic) as string
    if count = invalid then return ""
    if count = 1 then return "1 item"
    return count.ToStr() + " items"
end function
