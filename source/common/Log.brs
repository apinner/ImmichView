' Single logging helper. Return false here for release builds.
function logEnabled() as boolean
    return true
end function

sub logDebug(msg as dynamic)
    if logEnabled() then print "[immich] "; msg
end sub
