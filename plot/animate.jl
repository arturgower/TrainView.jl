using Plots

function animate(camera_reference::VideoCamera, trackprop::TrackProperties, df_distortions::DataFrame;
        Xspace = LinRange(5.0,20.0,60), maxframes::Int = min(140,size(distortions,1))
    )

    frame_numbers = size(df_distortions,1);

    h = 300;
    w = h * camera_reference.opticalproperties.sensor_width / camera_reference.opticalproperties.sensor_height
    pyplot(size = (w,h))

    # Set the limits of the image
    left_track  = [[x, -trackprop.track_gauge/2.0, 0.0 ] for x = Xspace];
    right_track = [[x, trackprop.track_gauge/2.0, 0.0] for x = Xspace];

    Luvs = camera_image(camera_reference, left_track);
    Ruvs = camera_image(camera_reference, right_track);

# Create a gif
    Lus = [uv[1] for uv in Luvs];
    Lvs = [uv[2] for uv in Luvs];
    Rus = [uv[1] for uv in Ruvs];
    Rvs = [uv[2] for uv in Ruvs];
    ulims = 1.5 .* (min(minimum(Rus),minimum(Lus)),max(maximum(Rus),maximum(Lus)))
    vlims = 1.5 .* (min(minimum(Rvs),minimum(Lvs)),max(maximum(Rvs),maximum(Lvs)))
    # vlims = (vlims[1] * (1 + sign(vlims[1]) * 0.2), vlims[2] * (1 + sign(vlims[2]) * 0.1))

    anim = @animate for n in Int.(round.(LinRange(1,frame_numbers,maxframes)))
        row = df_distortions[n,:]

        left_track  = [[x, -trackprop.track_gauge/2.0 + row[:β]*x^2, row[:α]*x^2] for x = Xspace]
        right_track = [[x, trackprop.track_gauge/2.0 + row[:β]*x^2, row[:α]*x^2] for x = Xspace]

        tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
        camera = VideoCamera(camera_reference, row)

        plot(tracks,camera, sleeper_displace = -0.09 * n,
            xlims = ulims, ylims = vlims,
            xguide = "", yguide = "",
            axis = false
        )
    end

    return anim
end
