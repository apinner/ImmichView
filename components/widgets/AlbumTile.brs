sub init()
    m.cover = m.top.findNode("cover")
    m.name = m.top.findNode("name")
    m.count = m.top.findNode("count")
    m.cover.setHttpAgent(createAuthAgent())
end sub

sub onContentChanged()
    item = m.top.itemContent
    if item = invalid then return
    m.cover.uri = item.thumbUrl
    m.name.text = item.title
    ' Places show their region and country instead of a count.
    if item.hasField("subtitle")
        m.count.text = item.subtitle
    else
        m.count.text = formatItemCount(item.assetCount)
    end if
end sub
