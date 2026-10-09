sub init()
    m.top.functionName = "runRequest"
end sub

sub runRequest()
    m.top.response = performRequest(m.top.method, m.top.path, m.top.body)
end sub

function performRequest(method as string, path as string, body as object) as object
    method = UCase(method)
    url = m.top.serverUrl + path
    port = CreateObject("roMessagePort")
    xfer = createTransfer(url, method, port)

    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.AddHeader("Content-Type", "application/json")
        payload = "{}"
        if body <> invalid then payload = FormatJson(body)
        started = xfer.AsyncPostFromString(payload)
    end if
    if not started then return makeResponse(false, -1, "network", "request could not start", invalid)

    msg = wait(m.top.timeoutMs, port)
    if msg = invalid
        xfer.AsyncCancel()
        logDebug(method + " " + path + " -> timeout")
        return makeResponse(false, 0, "timeout", "timed out", invalid)
    end if

    status = msg.GetResponseCode()
    logDebug(method + " " + path + " -> " + status.ToStr())
    if status < 0 then return makeResponse(false, status, "network", msg.GetFailureReason(), invalid)

    text = msg.GetString()
    data = invalid
    if text <> "" then data = ParseJson(text)

    if status >= 200 and status < 300
        if text <> "" and data = invalid then return makeResponse(false, status, "parse", "response was not JSON", invalid)
        return makeResponse(true, status, "", "", data)
    end if
    return makeResponse(false, status, "http", errorMessage(data, msg.GetFailureReason()), data)
end function

function createTransfer(url as string, method as string, port as object) as object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetRequest(method)
    if LCase(Left(url, 8)) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    xfer.AddHeader("Accept", "application/json")
    if m.top.apiKey <> "" then xfer.AddHeader("x-api-key", m.top.apiKey)
    xfer.RetainBodyOnError(true)
    xfer.EnableEncodings(true)
    return xfer
end function

' Immich errors look like { "message": "...", "error": "Unauthorized", "statusCode": 401 }.
function errorMessage(data as dynamic, fallback as string) as string
    if type(data) = "roAssociativeArray"
        msg = data.message
        if type(msg) = "roString" or type(msg) = "String" then return msg
        if type(msg) = "roArray" and msg.Count() > 0 then return FormatJson(msg)
    end if
    return fallback
end function

function makeResponse(ok as boolean, status as integer, kind as string, message as string, data as dynamic) as object
    return { ok: ok, status: status, kind: kind, message: message, data: data }
end function
