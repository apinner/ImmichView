function maxAttempts() as integer
    return 3
end function

function firstLockSeconds() as integer
    return 30
end function

sub init()
    m.dialog = invalid
    m.finished = false
    ' Reports the result just after the dialog has closed (see onClosed).
    m.reportTimer = m.top.createChild("Timer")
    m.reportTimer.duration = 0.05
    m.reportTimer.observeField("fire", "onReportTimer")
    ' Wrong-attempt counts and lock-outs live in m.global so they survive closing the prompt
    ' (until the app restarts): { <profile id>: { attempts, lockedUntil, lockSeconds } }.
    if not m.global.hasField("pinAttempts") then m.global.addFields({ pinAttempts: {} })
end sub

sub onStart()
    m.name = profileDisplayName(m.top.profile)
    if m.top.mode = "set"
        showPad("Choose a PIN", "Choose a " + pinLength().ToStr() + "-digit PIN for " + m.name + ". It's asked for when switching to this user or opening the app as them.", "onChooseButton")
    else if secondsLocked() > 0
        showLocked()
    else
        showPad("Enter PIN", "Enter the PIN for " + m.name + ".", "onVerifyButton")
    end if
end sub

' ---- Dialogs ----

sub showPad(title as string, message as string, handler as string)
    dlg = CreateObject("roSGNode", "StandardPinPadDialog")
    dlg.title = title
    dlg.message = [message]
    dlg.buttons = ["OK", "Cancel"]
    if dlg.textEditBox <> invalid
        dlg.textEditBox.maxTextLength = pinLength()
        dlg.textEditBox.secureMode = true
    end if
    dlg.observeField("buttonSelected", handler)
    dlg.observeField("wasClosed", "onClosed")
    m.dialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub showLocked()
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Too many wrong PINs"
    dlg.message = ["Try again in " + secondsLocked().ToStr() + " seconds."]
    dlg.buttons = ["OK"]
    dlg.observeField("buttonSelected", "onLockedButton")
    dlg.observeField("wasClosed", "onClosed")
    m.dialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub onLockedButton()
    finish("cancelled")
end sub

' The current dialog has closed: Back cancels, otherwise report the result finish() chose.
' The result is reported a moment later, not from inside wasClosed: Roku clears the scene's
' dialog after wasClosed observers run, which would dismiss a dialog the caller opens next
' (e.g. verify, then choose a new PIN). Replaced dialogs are ignored.
sub onClosed(event as object)
    if m.dialog = invalid or not event.getRoSGNode().isSameNode(m.dialog) then return
    m.dialog = invalid
    if not m.finished
        m.finished = true
        m.pendingResult = "cancelled"
    end if
    m.reportTimer.control = "start"
end sub

sub onReportTimer()
    m.top.result = m.pendingResult
end sub

sub finish(result as string)
    if m.finished then return
    m.finished = true
    m.pendingResult = result
    if m.dialog <> invalid
        m.dialog.close = true  ' onClosed reports the result
    else
        m.reportTimer.control = "start"
    end if
end sub

function enteredPin() as string
    return m.dialog.pin.Trim()
end function

function isFullPin(pin as string) as boolean
    return Len(pin) = pinLength() and CreateObject("roRegex", "^[0-9]+$", "").IsMatch(pin)
end function

' ---- Verify ----

sub onVerifyButton()
    if m.dialog.buttonSelected <> 0
        finish("cancelled")
        return
    end if
    pin = enteredPin()
    if not isFullPin(pin)
        showPad("Enter PIN", "Enter all " + pinLength().ToStr() + " digits of the PIN for " + m.name + ".", "onVerifyButton")
        return
    end if
    if checkProfilePin(m.top.profile, pin)
        clearAttempts()
        finish("ok")
        return
    end if
    if recordWrongAttempt()
        m.dialog.close = true
        showLocked()
    else
        showPad("Enter PIN", "That PIN isn't right. Enter the PIN for " + m.name + ".", "onVerifyButton")
    end if
end sub

function attemptState() as object
    attempts = m.global.pinAttempts
    state = attempts[m.top.profile.id]
    if state = invalid then state = { attempts: 0, lockedUntil: 0, lockSeconds: firstLockSeconds() }
    return state
end function

sub saveAttemptState(state as object)
    attempts = m.global.pinAttempts
    attempts[m.top.profile.id] = state
    m.global.pinAttempts = attempts
end sub

function nowSeconds() as integer
    return CreateObject("roDateTime").AsSeconds()
end function

function secondsLocked() as integer
    remaining = attemptState().lockedUntil - nowSeconds()
    if remaining < 0 then return 0
    return remaining
end function

' Returns true when this wrong attempt starts a lock-out.
function recordWrongAttempt() as boolean
    state = attemptState()
    state.attempts = state.attempts + 1
    locked = state.attempts >= maxAttempts()
    if locked
        state.lockedUntil = nowSeconds() + state.lockSeconds
        state.lockSeconds = state.lockSeconds * 2
        state.attempts = 0
    end if
    saveAttemptState(state)
    return locked
end function

sub clearAttempts()
    attempts = m.global.pinAttempts
    attempts.Delete(m.top.profile.id)
    m.global.pinAttempts = attempts
end sub

' ---- Set (entered twice) ----

sub onChooseButton()
    if m.dialog.buttonSelected <> 0
        finish("cancelled")
        return
    end if
    pin = enteredPin()
    if not isFullPin(pin)
        showPad("Choose a PIN", "Enter " + pinLength().ToStr() + " digits for " + m.name + "'s PIN.", "onChooseButton")
        return
    end if
    m.firstPin = pin
    showPad("Confirm the PIN", "Enter the same PIN again to confirm it.", "onConfirmButton")
end sub

sub onConfirmButton()
    if m.dialog.buttonSelected <> 0
        finish("cancelled")
        return
    end if
    if enteredPin() <> m.firstPin
        showPad("Choose a PIN", "The PINs didn't match. Choose a " + pinLength().ToStr() + "-digit PIN for " + m.name + ".", "onChooseButton")
        return
    end if
    m.top.newPin = m.firstPin
    finish("ok")
end sub
