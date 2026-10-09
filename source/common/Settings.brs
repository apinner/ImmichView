' Persistent settings in roRegistrySection("immich").

function loadSettings() as object
    sec = CreateObject("roRegistrySection", "immich")
    return {
        serverUrl: sec.Read("serverUrl")
        apiKey: sec.Read("apiKey")
    }
end function

sub saveSettings(serverUrl as string, apiKey as string)
    sec = CreateObject("roRegistrySection", "immich")
    sec.Write("serverUrl", serverUrl)
    sec.Write("apiKey", apiKey)
    sec.Flush()
end sub

function hasSettings(settings as object) as boolean
    return settings.serverUrl <> "" and settings.apiKey <> ""
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
