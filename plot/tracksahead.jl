@recipe function plot(tracks::TracksAhead, camera::VideoCamera; sleeper_displace = 0.0, camera_grid = true, sleepers = true)

    trackproperties = tracks.trackproperties

    # calculate tracks in the camera image
    uvLs = camera_image(camera, tracks.left_track);
    uvRs = camera_image(camera, tracks.right_track);

    uLs = [uv[1] for uv in uvLs];
    uRs = [uv[1] for uv in uvRs];
    vLs = [uv[2] for uv in uvLs];
    vRs = [uv[2] for uv in uvRs];

    uvL2s = camera_image(camera, [[t[1],t[2] - trackproperties.track_width, t[3]] for t in tracks.left_track]);
    uvR2s = camera_image(camera, [[t[1],t[2] + trackproperties.track_width, t[3]] for t in tracks.right_track]);

    uL2s = [uv[1] for uv in uvL2s];
    uR2s = [uv[1] for uv in uvR2s];
    vL2s = [uv[2] for uv in uvL2s];
    vR2s = [uv[2] for uv in uvR2s];

    Ymax = 0.8 * trackproperties.track_gauge;
    Xmax = maximum(t[1] for t in tracks.left_track) / 2 + maximum(t[1] for t in tracks.right_track) / 2
    Xmin = minimum(t[1] for t in tracks.left_track) / 2 + minimum(t[1] for t in tracks.right_track) / 2
    # Xmin = 0.0

    # calculate sleepers in the camera image
    sw = trackproperties.sleeper_width
    sd = trackproperties.sleeper_distance

    left_distances = cumsum(norm.(circshift(tracks.left_track,1)[2:end] - tracks.left_track[2:end]))
    left_distances = [0.0; left_distances]

    right_distances = cumsum(norm.(circshift(tracks.right_track,1)[2:end] - tracks.right_track[2:end]))
    right_distances = [0.0; right_distances]

    no = - floor(sleeper_displace/(sd + sw))
    sleeper_number = -1 + Int(min(
        - no + floor((left_distances[end] - sleeper_displace) / (sd + sw)),
        - no + floor((right_distances[end] - sleeper_displace) / (sd + sw))
    ))

    sleepers_uv = map(0:sleeper_number) do i
        t = findfirst((i+no) * (sd + sw) + sleeper_displace .<= left_distances)
        if t == length(left_distances) t = t - 1 end

        v = tracks.left_track[t+1] - tracks.left_track[t];
        v = v / norm(v);

        p1 =  tracks.left_track[t] + ((i+no) * (sd + sw) + sleeper_displace - left_distances[t]) .* v
        p2 =  tracks.left_track[t] + ((i+no) * (sd + sw) + sw + sleeper_displace - left_distances[t]) .* v

        t = findfirst((i+no) * (sd + sw) + sleeper_displace .< right_distances)
        if t == length(left_distances) t = t - 1 end

        v = tracks.right_track[t+1] - tracks.right_track[t];
        v = v / norm(v);

        p3 =  tracks.right_track[t] + ((i+no) * (sd + sw) + sw + sleeper_displace - right_distances[t]) .* v
        p4 =  tracks.right_track[t] + ((i+no) * (sd + sw) + sleeper_displace - right_distances[t]) .* v

        sleeper_XYZ = [p1,p2,p3,p4]

        camera_image(camera,sleeper_XYZ)
    end


    # Plot the camera grid
    if camera_grid
        @series begin
            Xmax --> Xmax
            Xmin --> Xmin
            Ymax --> Ymax
            camera
        end
    end

    # plot the sleepers

    for uvs in sleepers_uv
        if sleepers
            @series begin
                linecolor --> :black
                fillcolor --> :brown
                fillalpha --> 0.6
                linewidth --> 0.1
                label --> ""
                seriestype := :shape
                [uv[1] for uv in uvs], [uv[2] for uv in uvs]
            end
        end
    end

    # plot the left tracks
    @series begin
        linecolor --> :black
        fillcolor --> :red
        fillalpha --> 0.8
        linewidth --> 0.1
        label --> ""
        seriestype := :shape
        [uLs;reverse(uL2s)], [vLs;reverse(vL2s)]
    end

    # plot the right tracks
    @series begin
        yflip := true
        grid --> false
        xguide --> "u"
        yguide --> "v"
        aspect_ratio := 1.0
        label --> ""
        linecolor --> :black
        fillcolor --> :red
        fillalpha --> 0.8
        linewidth --> 0.1
        seriestype := :shape
        [uRs;reverse(uR2s)], [vRs;reverse(vR2s)]
    end

end

@recipe function plot(camera::VideoCamera; Xdisplace = 0.0, Xmin = 1.0, Xmax = 20.0, Ymax = 1.5, Ymin = - Ymax, mesh_number = 6)

    Yspace = LinRange(Ymin,Ymax,mesh_number)
    dy = (Yspace[2] - Yspace[1])
    no = - floor(Xdisplace/dy)

    # Xspace = [reverse(min(Xmax,Xmin+Xdisplace):-(Yspace[2] - Yspace[1]):Xmin); (Xmin+Xdisplace):(Yspace[2] - Yspace[1]):Xmax ]
    Xspace = (Xmin + Xdisplace + no*dy):dy:Xmax

    hlines = [ [[x, y, 0.0] for y in Yspace] for x in Xspace];
    vlines = [ [[x, y, 0.0] for x in Xspace] for y in Yspace];

    cam_hlines = map(hlines) do h
        uvs = camera_image(camera, h)
        us = [uv[1] for uv in uvs]
        vs = [uv[2] for uv in uvs]
        [us, vs]
    end;
    cam_vlines = map(vlines) do v
        uvs = camera_image(camera, v)
        us = [uv[1] for uv in uvs]
        vs = [uv[2] for uv in uvs]
        [us, vs]
    end;

    for cam in [cam_hlines; cam_vlines]
        @series begin
            grid --> false
            xguide --> "u"
            yguide --> "v"
            aspect_ratio := 1.0
            label --> ""
            linecolor --> :gray
            linealpha --> 0.3
            linewidth --> 0.5
            yflip := true

            (cam[1],cam[2])
        end
    end
end

# pyplot(size = (400,300))
# plot()
# [plot!(cam[1],cam[2],grid=false, linecolor = :gray,label = "",linealpha = 0.3, linewidth = 0.5) for cam in [cam_hlines; cam_vlines]];
# gui()
