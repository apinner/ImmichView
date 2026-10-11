sub init()
    m.anim = m.top.findNode("anim")
end sub

sub onCountdown()
    m.anim.control = "stop"
    m.anim.duration = m.top.countdown
    m.anim.control = "start"
end sub

sub onStop()
    m.anim.control = "stop"
end sub
