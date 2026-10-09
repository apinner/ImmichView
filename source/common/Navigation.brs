' Where to go when an item in a TimelineView is selected: videos play straight away,
' photos open in the viewer (which can step through the rest of the timeline).
function assetNavigation(timeline as object, selected as object) as object
    if selected.asset.isVideo
        return { screen: "VideoPlayer", params: { asset: selected.asset } }
    end if
    return { screen: "PhotoViewer", params: { open: { timeline: timeline, index: selected.index } } }
end function
