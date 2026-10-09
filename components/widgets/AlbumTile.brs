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
    m.count.text = formatItemCount(item.assetCount)
end sub
