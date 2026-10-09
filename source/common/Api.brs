' Render-thread helpers for starting ImmichApiTask requests.

' Starts one request. `callback` is the name of a sub in the calling component
' that receives the roSGNodeEvent for the task's `response` field.
' Keep a reference to the returned task until the callback fires.
function startApiRequest(settings as object, method as string, path as string, callback as string, body = invalid as dynamic) as object
    task = CreateObject("roSGNode", "ImmichApiTask")
    task.serverUrl = settings.serverUrl
    task.apiKey = settings.apiKey
    task.method = method
    task.path = path
    if body <> invalid then task.body = body
    task.observeField("response", callback)
    task.control = "RUN"
    return task
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
    if resp.status = 401 or resp.status = 403
        return "The API key was rejected. Create a new one in Immich under Account Settings > API Keys."
    end if
    if resp.kind = "parse"
        return "The server answered, but not like Immich does. If you use a reverse proxy, check the URL and that it isn't showing a login page."
    end if
    return "Server error " + resp.status.ToStr() + ": " + resp.message
end function
