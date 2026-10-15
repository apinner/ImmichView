#if DEV
' Dev convenience: sideloading wipes the registry, so tools\relaunch.ps1 passes
' serverUrl and apiKey (from .env) as ECP launch parameters to avoid retyping them.
' resetProfiles=true first removes every saved user (e.g. to take store screenshots with
' only a demo account).
' Compiled out of release builds: anyone on the network could otherwise reconfigure the channel.
sub applyDevLaunchSettings(args as dynamic)
    if type(args) <> "roAssociativeArray" then return
    if args.resetProfiles = "true"
        saveProfiles([], "")
        logDebug("removed all users (launch parameter)")
    end if
    if args.serverUrl = invalid or args.apiKey = invalid then return
    serverUrl = normalizeServerUrl(args.serverUrl)
    name = ""
    if args.profileName <> invalid then name = args.profileName
    upsertProfile(name, serverUrl, args.apiKey)
    ' extraProfile=<name> adds another user with the same server and key (e.g. to show the
    ' Who's watching picker in store screenshots with only a demo account).
    if args.extraProfile <> invalid and args.extraProfile <> ""
        data = loadProfiles()
        data.profiles.Push({ id: CreateObject("roDeviceInfo").GetRandomUUID(), name: args.extraProfile, serverUrl: serverUrl, apiKey: args.apiKey })
        saveProfiles(data.profiles, data.activeId)
    end if
    logDebug("settings applied from launch parameters")
end sub
#end if
