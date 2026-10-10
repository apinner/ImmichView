function searchPlaceholder() as string
    return "Search your photos, e.g. beach, birthday cake, snow"
end function

sub init()
    m.box = m.top.findNode("box")
    m.boxBack = m.top.findNode("boxBack")
    m.boxText = m.top.findNode("boxText")
    m.resultsView = m.top.findNode("resultsView")
    m.top.results = m.resultsView
    m.query = ""
    m.inResults = false   ' where focus returns to, e.g. after closing the photo viewer
    m.boxText.text = searchPlaceholder()

    m.resultsView.observeField("itemSelected", "onResultSelected")
    m.resultsView.observeField("exitedTop", "focusBox")
    m.box.observeField("focusedChild", "updateBoxStyle")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if not m.top.hasFocus() then return
    if m.inResults and m.resultsView.assetCount > 0
        focusResults()
    else
        focusBox()
    end if
end sub

sub focusBox()
    m.inResults = false
    m.box.setFocus(true)
end sub

sub focusResults()
    m.inResults = true
    m.resultsView.setFocus(true)
end sub

sub updateBoxStyle()
    if m.box.hasFocus()
        m.boxBack.color = "0xADCBFAFF"
        m.boxText.color = "0x101418FF"
    else
        m.boxBack.color = "0x262C34FF"
        if m.query = ""
            m.boxText.color = "0x80888FFF"
        else
            m.boxText.color = "0xE0E4E8FF"
        end if
    end if
end sub

sub onResultSelected()
    m.top.itemSelected = m.resultsView.itemSelected
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.box.hasFocus()
        if key = "OK"
            showKeyboard()
            return true
        else if key = "down" and m.resultsView.assetCount > 0
            focusResults()
            return true
        end if
    else if key = "back" and m.resultsView.isInFocusChain()
        focusBox()
        return true
    end if
    return false
end function

' ---- Keyboard / voice ----

sub showKeyboard()
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = "Search photos"
    dlg.message = ["Describe what you're looking for, like " + Chr(34) + "dog on the beach" + Chr(34) + ". Use the mic button to speak."]
    dlg.text = m.query
    dlg.buttons = ["Search", "Cancel"]
    dlg.observeField("buttonSelected", "onKeyboardButton")
    dlg.observeField("wasClosed", "onKeyboardClosed")
    m.dialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub onKeyboardButton()
    if m.dialog.buttonSelected = 0
        text = m.dialog.text.Trim()
        if text <> "" then runSearch(text)
    end if
    m.dialog.close = true
end sub

sub onKeyboardClosed()
    m.dialog = invalid
    focusBox()
end sub

sub runSearch(text as string)
    m.query = text
    m.boxText.text = text
    logDebug("search: " + text)
    ' Clear first so searching the same text again still triggers a new search.
    m.resultsView.searchText = ""
    m.resultsView.searchText = text
end sub
