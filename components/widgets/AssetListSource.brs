sub onAssetsChanged()
    m.top.assetCount = m.top.assets.Count()
end sub

function getAsset(index as integer) as dynamic
    assets = m.top.assets
    if index < 0 or index >= assets.Count() then return invalid
    return assets[index]
end function

function requestMore() as boolean
    return false
end function
