' Persistent settings in roRegistrySection("immich").
' Users are stored as profiles, each with its own server and API key:
'   profiles      = JSON array of { id, name, serverUrl, apiKey }
'   activeProfile = id of the profile in use

function registrySection() as object
    return CreateObject("roRegistrySection", "immich")
end function

function loadProfiles() as object
    sec = registrySection()
    profiles = invalid
    raw = sec.Read("profiles")
    if raw <> "" then profiles = ParseJson(raw)
    if type(profiles) <> "roArray" then profiles = []
    return { profiles: profiles, activeId: sec.Read("activeProfile") }
end function

sub saveProfiles(profiles as object, activeId as string)
    sec = registrySection()
    sec.Write("profiles", FormatJson(profiles))
    sec.Write("activeProfile", activeId)
    sec.Flush()
end sub

' The active profile, or one with empty fields when there isn't one.
function loadSettings() as object
    data = loadProfiles()
    for each profile in data.profiles
        if profile.id = data.activeId then return profile
    end for
    return { id: "", name: "", serverUrl: "", apiKey: "" }
end function

function hasSettings(settings as object) as boolean
    return settings.serverUrl <> "" and settings.apiKey <> ""
end function

' Adds a profile, or updates the one with the same server and key, and makes it active.
function upsertProfile(name as string, serverUrl as string, apiKey as string) as string
    data = loadProfiles()
    target = invalid
    for each profile in data.profiles
        if profile.serverUrl = serverUrl and profile.apiKey = apiKey then target = profile
    end for
    if target = invalid
        target = { id: CreateObject("roDeviceInfo").GetRandomUUID(), name: name, serverUrl: serverUrl, apiKey: apiKey }
        data.profiles.Push(target)
    else if name <> ""
        target.name = name
    end if
    saveProfiles(data.profiles, target.id)
    return target.id
end function

sub setActiveProfile(id as string)
    saveProfiles(loadProfiles().profiles, id)
end sub

sub setProfileName(id as string, name as string)
    data = loadProfiles()
    for each profile in data.profiles
        if profile.id = id then profile.name = name
    end for
    saveProfiles(data.profiles, data.activeId)
end sub

' Removes a profile. If it was active, the first remaining profile becomes active.
sub removeProfile(id as string)
    data = loadProfiles()
    kept = []
    for each profile in data.profiles
        if profile.id <> id then kept.Push(profile)
    end for
    activeId = data.activeId
    if activeId = id
        activeId = ""
        if kept.Count() > 0 then activeId = kept[0].id
    end if
    saveProfiles(kept, activeId)
end sub

function profileDisplayName(profile as object) as string
    if profile.name = invalid or profile.name = "" then return "Unnamed user"
    return profile.name
end function

' "https://photos.example.com" -> "photos.example.com"
function serverHost(serverUrl as string) as string
    host = serverUrl
    if LCase(Left(host, 8)) = "https://" then host = Mid(host, 9)
    if LCase(Left(host, 7)) = "http://" then host = Mid(host, 8)
    return host
end function

' Accepts "192.168.1.20:2283", "https://photos.example.com/", ".../api" and
' returns the base URL with a scheme and no trailing slash or /api suffix.
function normalizeServerUrl(raw as string) as string
    url = raw.Trim()
    if url = "" then return ""

    lower = LCase(url)
    if Left(lower, 7) <> "http://" and Left(lower, 8) <> "https://"
        url = "http://" + url
    end if
    while Right(url, 1) = "/"
        url = Left(url, Len(url) - 1)
    end while
    if LCase(Right(url, 4)) = "/api"
        url = Left(url, Len(url) - 4)
    end if
    return url
end function
