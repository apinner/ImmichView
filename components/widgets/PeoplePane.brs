sub init()
    m.grid = m.top.findNode("grid")
    m.status = m.top.findNode("status")
    m.loaded = false
    m.grid.observeField("itemSelected", "onPersonSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

' Focus goes to the grid once it has people; until then the pane keeps it (Up returns to the tabs).
sub onFocusChanged()
    if m.top.hasFocus() and m.grid.content <> invalid then m.grid.setFocus(true)
end sub

sub onLoad()
    if not m.top.load or m.loaded then return
    m.loaded = true
    m.status.text = "Loading people..."
    m.task = startApiRequest(currentSettings(), "GET", "/api/people?withHidden=false&size=1000", "onPeople")
end sub

sub onPeople(event as object)
    resp = event.getData()
    m.task = invalid
    if not resp.ok
        m.loaded = false
        m.status.text = describeApiError(resp)
        return
    end if

    ' Immich lists named people first; unnamed face clusters are left out.
    content = CreateObject("roSGNode", "ContentNode")
    for each person in resp.data.people
        if person.name <> invalid and person.name <> "" then addPerson(content, person)
    end for
    if content.getChildCount() = 0
        m.status.text = "No named people yet. Name faces in the Immich web app under Explore > People."
        return
    end if
    m.status.text = ""
    m.grid.content = content
    if m.top.isInFocusChain() then m.grid.setFocus(true)
end sub

sub addPerson(content as object, person as object)
    item = content.createChild("ContentNode")
    item.update({
        title: person.name
        personId: person.id
        thumbUrl: m.global.serverUrl + "/api/people/" + person.id + "/thumbnail"
    }, true)
end sub

sub onPersonSelected()
    item = m.grid.content.getChild(m.grid.itemSelected)
    m.top.personSelected = { id: item.personId, name: item.title }
end sub
