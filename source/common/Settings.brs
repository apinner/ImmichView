' Persistent settings in roRegistrySection("immich").
' Users are stored as profiles, each with its own server and API key:
'   profiles      = JSON array of { id, name, serverUrl, apiKey, pinSalt?, pinHash? }
'   activeProfile = id of the profile in use ("" when none is chosen, e.g. after removing it)

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
' clearPin: signing in again with a user's API key proves access, so it resets a forgotten PIN.
function upsertProfile(name as string, serverUrl as string, apiKey as string, clearPin = false as boolean) as string
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
    if clearPin then removePinFields(target)
    saveProfiles(data.profiles, target.id)
    return target.id
end function

function findProfile(id as string) as dynamic
    for each profile in loadProfiles().profiles
        if profile.id = id then return profile
    end for
    return invalid
end function

sub setActiveProfile(id as string)
    saveProfiles(loadProfiles().profiles, id)
end sub

' The user's Immich profile photo URL ("" if they have none), remembered so the Who's
' watching tiles show it straight away.
function profileAvatar(profile as dynamic) as string
    if profile = invalid or profile.avatar = invalid then return ""
    return profile.avatar
end function

sub setProfileAvatar(id as string, url as string)
    data = loadProfiles()
    for each profile in data.profiles
        if profile.id = id then profile.avatar = url
    end for
    saveProfiles(data.profiles, data.activeId)
end sub

' The profile photo URL from an Immich /users/me response, or "".
function avatarUrlFor(serverUrl as string, user as object) as string
    if user.profileImagePath = invalid or user.profileImagePath = "" then return ""
    return serverUrl + "/api/users/" + user.id + "/profile-image"
end function

sub setProfileName(id as string, name as string)
    data = loadProfiles()
    for each profile in data.profiles
        if profile.id = id then profile.name = name
    end for
    saveProfiles(data.profiles, data.activeId)
end sub

' Removes a profile. If it was active, no profile is active afterwards: MainScene shows the
' Who's watching picker rather than opening another user (who may have a PIN).
sub removeProfile(id as string)
    data = loadProfiles()
    kept = []
    for each profile in data.profiles
        if profile.id <> id then kept.Push(profile)
    end for
    activeId = data.activeId
    if activeId = id then activeId = ""
    saveProfiles(kept, activeId)
end sub

' ---- User PINs ----
' A household privacy lock between adults, not security: the API key itself is stored on the
' device. Profiles keep a random salt and the SHA-256 of salt + PIN, never the PIN.

function pinLength() as integer
    return 4
end function

function hashPin(pin as string, salt as string) as string
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(salt + pin)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha256")
    return digest.Process(bytes)
end function

function profileHasPin(profile as dynamic) as boolean
    return profile <> invalid and profile.pinHash <> invalid and profile.pinHash <> ""
end function

function checkProfilePin(profile as object, pin as string) as boolean
    return profileHasPin(profile) and hashPin(pin, profile.pinSalt) = profile.pinHash
end function

sub setProfilePin(id as string, pin as string)
    data = loadProfiles()
    for each profile in data.profiles
        if profile.id = id
            profile.pinSalt = CreateObject("roDeviceInfo").GetRandomUUID()
            profile.pinHash = hashPin(pin, profile.pinSalt)
        end if
    end for
    saveProfiles(data.profiles, data.activeId)
end sub

sub clearProfilePin(id as string)
    data = loadProfiles()
    for each profile in data.profiles
        if profile.id = id then removePinFields(profile)
    end for
    saveProfiles(data.profiles, data.activeId)
end sub

' Dot-notation writes (profile.pinSalt = ...) store lowercase keys, and ParseJson's dictionaries
' are case-sensitive, so Delete needs the lowercase names; the mixed-case ones are for safety.
sub removePinFields(profile as object)
    for each key in ["pinsalt", "pinhash", "pinSalt", "pinHash"]
        profile.Delete(key)
    end for
end sub

' ---- Slideshow (shared by all users) ----

function slideshowIntervals() as object
    return [3, 5, 10, 15, 30, 60]
end function

function loadSlideshowSeconds() as integer
    raw = registrySection().Read("slideshowSeconds")
    if raw = "" then return 5
    return raw.ToInt()
end function

sub saveSlideshowSeconds(seconds as integer)
    sec = registrySection()
    sec.Write("slideshowSeconds", seconds.ToStr())
    sec.Flush()
end sub

' ---- Photos / videos filter (shared by all users) ----
' "all", "photos" or "videos"; applies to the timeline, albums, people and search.

function mediaFilters() as object
    return ["all", "photos", "videos"]
end function

function loadMediaFilter() as string
    value = registrySection().Read("mediaFilter")
    if value = "photos" or value = "videos" then return value
    return "all"
end function

sub saveMediaFilter(value as string)
    sec = registrySection()
    sec.Write("mediaFilter", value)
    sec.Flush()
end sub

' ---- Screensaver (shared by all users) ----
' source: "random" (whole library), "memories" (on this day) or "album" (albumId/albumName)

function loadScreensaverSettings() as object
    sec = registrySection()
    source = sec.Read("ssSource")
    if source = "" then source = "random"
    return {
        source: source
        albumId: sec.Read("ssAlbumId")
        albumName: sec.Read("ssAlbumName")
        showCaption: sec.Read("ssCaption") <> "off"
        showClock: sec.Read("ssClock") = "on"
    }
end function

sub saveScreensaverClock(show as boolean)
    saveOnOff("ssClock", show)
end sub

' ---- Photo viewer (shared by all users) ----

' Names of the people in a photo, small at the bottom left. Off unless turned on.
function loadShowPeopleNames() as boolean
    return registrySection().Read("showPeople") = "on"
end function

sub saveShowPeopleNames(show as boolean)
    saveOnOff("showPeople", show)
end sub

' Behind photos that don't fill the screen: "default" (the app colour), "black", "glow"
' (a dim wash of the photo's colours) or "blur" (a blurred copy of the photo).
function photoBackgrounds() as object
    return ["default", "black", "glow", "blur"]
end function

function loadPhotoBackground() as string
    value = registrySection().Read("photoBackground")
    for each option in photoBackgrounds()
        if option = value then return value
    end for
    return "default"
end function

sub savePhotoBackground(value as string)
    sec = registrySection()
    sec.Write("photoBackground", value)
    sec.Flush()
end sub

function photoBackgroundLabel(value as string) as string
    if value = "black" then return "Black"
    if value = "glow" then return "Ambient glow"
    if value = "blur" then return "Blur"
    return "Default"
end function

sub saveOnOff(key as string, value as boolean)
    sec = registrySection()
    if value then sec.Write(key, "on") else sec.Write(key, "off")
    sec.Flush()
end sub

sub saveScreensaverSource(source as string, albumId as string, albumName as string)
    sec = registrySection()
    sec.Write("ssSource", source)
    sec.Write("ssAlbumId", albumId)
    sec.Write("ssAlbumName", albumName)
    sec.Flush()
end sub

sub saveScreensaverCaption(show as boolean)
    saveOnOff("ssCaption", show)
end sub

function screensaverSourceLabel(settings as object) as string
    if settings.source = "memories" then return "Memories (on this day)"
    if settings.source = "album" then return "Album: " + settings.albumName
    return "Random photos from your library"
end function

' ---- Display helpers ----

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
