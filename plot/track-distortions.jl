@recipe function plot(camera_reference::VideoCamera, trackprop::TrackProperties;
        dict_distortion = Dict(),
        sleeper_displace = 0.0, camera_grid = true,
        Xspace = LinRange(5.0,20.0,60)
    )

    # extract curvature
    α = haskey(dict_distortion,:α) ? dict_distortion[:α] : 0.0
    β = haskey(dict_distortion,:β) ? dict_distortion[:β] : 0.0

    left_track  = [[x, -trackprop.track_gauge/2.0 + β*x^2, α*x^2] for x = Xspace]
    right_track = [[x, trackprop.track_gauge/2.0 + β*x^2, α*x^2] for x = Xspace]

    tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
    camera = VideoCamera(camera_reference, dict_distortion)

    @series begin
        xguide --> ""
        yguide --> ""
        axis --> false
        tracks, camera
    end
end
