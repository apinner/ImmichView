' Places "View" straight after "Immich", whatever width the system font gives it.
sub init()
    first = m.top.findNode("first")
    m.top.findNode("second").translation = [89 + first.boundingRect().width, 0]
end sub
