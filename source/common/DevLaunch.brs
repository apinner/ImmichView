#if DEV
' Dev convenience: sideloading wipes the registry, so tools\relaunch.ps1 passes
' serverUrl and apiKey (from .env) as ECP launch parameters to avoid retyping them.
' Compiled out of release builds: anyone on the network could otherwise reconfigure the channel.
sub applyDevLaunchSettings(args as dynamic)
    if type(args) <> "roAssociativeArray" then return
    if args.serverUrl = invalid or args.apiKey = invalid then return
    upsertProfile("", normalizeServerUrl(args.serverUrl), args.apiKey)
    logDebug("settings applied from launch parameters")
end sub
#end if
