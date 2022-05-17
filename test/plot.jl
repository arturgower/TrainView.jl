@testset "test plot recipes" begin

    trackprop = TrackProperties(track_gauge = 1.435)

    cameraposition = [0.0,-0.2,-2.4];

    camera = VideoCamera(cameraposition)
    dict = Dict(:α => 0.01,:β => -0.003, :Y => 0.5, :Z => 0.2)


    rail_axis = LinRange(5.0,20.0,60)

    left_track  = [[x, -trackprop.track_gauge/2.0 + 0.01*x^2, 0.01*x^2] for x = rail_axis]
    right_track = [[x, trackprop.track_gauge/2.0 + 0.01*x^2, 0.01*x^2] for x = rail_axis]

    tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)

    # plot(tracks, camera)
    # plot(camera, trackprop; dict_distortion = dict)

    @test true
end
