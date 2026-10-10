' Render-thread helpers for Immich requests and authenticated images.
' Components that include this need m.global.serverUrl / m.global.apiKey (set by MainScene).

function currentSettings() as object
    return { serverUrl: m.global.serverUrl, apiKey: m.global.apiKey }
end function

' Starts one request. `callback` is the name of a sub in the calling component
' that receives the roSGNodeEvent for the task's `response` field.
' Keep a reference to the returned task until the callback fires.
function startApiRequest(settings as object, method as string, path as string, callback as string, body = invalid as dynamic, timeoutMs = 10000 as integer) as object
    task = CreateObject("roSGNode", "ImmichApiTask")
    task.serverUrl = settings.serverUrl
    task.apiKey = settings.apiKey
    task.method = method
    task.path = path
    task.timeoutMs = timeoutMs
    if body <> invalid then task.body = body
    task.observeField("response", callback)
    task.control = "RUN"
    return task
end function

' HTTP agent carrying the API key, for Poster and Video nodes.
function createAuthAgent() as object
    agent = CreateObject("roHttpAgent")
    agent.AddHeader("x-api-key", m.global.apiKey)
    if LCase(Left(m.global.serverUrl, 8)) = "https://"
        agent.SetCertificatesFile("common:/certs/ca-bundle.crt")
        agent.InitClientCertificates()
    end if
    return agent
end function

' size: "thumbnail" (grids) or "preview" (full screen). Never "original" in a Poster.
function thumbnailUrl(assetId as dynamic, size as string) as string
    if assetId = invalid or assetId = "" then return ""
    return m.global.serverUrl + "/api/assets/" + assetId + "/thumbnail?size=" + size
end function

' Query values here are UUIDs and ISO dates; only ':' and '+' need escaping.
function escapeQueryValue(value as string) as string
    return value.Replace(":", "%3A").Replace("+", "%2B")
end function

' Turns a failed response into a message suitable for the screen.
function describeApiError(resp as object) as string
    if resp.kind = "timeout"
        return "The server didn't respond in time. Check the URL and that the Roku can reach it."
    end if
    if resp.kind = "network"
        status = resp.status
        if status = -6
            return "Couldn't find that server name. Check the URL."
        else if status = -7
            return "Couldn't connect to the server. Check the address and port, and that the Roku is on the same network."
        else if status = -35 or status = -51 or status = -60
            return "The server's HTTPS certificate couldn't be verified."
        end if
        return "Couldn't reach the server (" + resp.message + ")."
    end if
    if resp.status = 401
        return "The API key was rejected. Create a new one in Immich under Account Settings > API Keys."
    end if
    if resp.status = 403
        return "The API key doesn't have permission for this. Give it more permissions in Immich, or create a key with all permissions."
    end if
    if resp.kind = "parse"
        return "The server answered, but not like Immich does. If you use a reverse proxy, check the URL and that it isn't showing a login page."
    end if
    return "Server error " + resp.status.ToStr() + ": " + resp.message
end function
