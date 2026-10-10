' Single logging helper: on in dev builds (bs_const DEV=true, set by deploy.ps1), off in release.
function logEnabled() as boolean
    #if DEV
        return true
    #else
        return false
    #end if
end function

sub logDebug(msg as dynamic)
    if logEnabled() then print "[immich] "; msg
end sub
