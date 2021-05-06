include("TrainView.jl")

maxframes = 400

max_curvature = 1e-3

## Define the reference camera
    cameraposition_reference = [0.0,0.6,-2.165];
    ψθφ_ref = [0.0,-19.1,-7.28] .* (pi/180.0);

    camera_reference = VideoCamera(cameraposition_reference;
        sensor_height = 720,
        sensor_width = 1280,
        focal_length = 5.8e-3,
        pixelspermeter = 1 / 5.5e-6,
        ψθφ = ψθφ_ref
    );


    ## Define the reference camera
        cameraposition_reference = [0.0,0.6,-2.165];
        ψθφ_ref = [0.0,-19.1,-7.28] .* (pi/180.0);

        camera_reference = VideoCamera(cameraposition_reference;
            sensor_height = 720,
            sensor_width = 1280,
            focal_length = 5.8e-3,
            pixelspermeter = 1 / 5.5e-6,
            ψθφ = ψθφ_ref
        );

## Define disturbances of the whole journey

# horizontal and vertical curvatures
    βs = [max_curvature * cos(8n * 2pi / maxframes)  for n in 1:maxframes]
    αs = [max_curvature * cos(4n * 2pi / maxframes)  for n in 1:maxframes]

# displacements relative to the track
    choose_distortions = [:Y,:Z,:ψ,:θ,:φ];
    max_distortions = [[0.05,0.06]; pi/180 .* [2.0,2.0,0.2]]

    Nsmooth = Int(round(maxframes / 20))
    Ncut_high = Int(round(maxframes / 35))
    Ncut_low = Int(round(maxframes / 130))

    distortions = map(max_distortions) do dsmax
        ds = 2 .* rand(maxframes+Nsmooth) .- 1.0
        fftds = fft(ds)
        fftds[Ncut_high:end-Ncut_high] .= 0.0
        fftds[1:Ncut_low] .= 0.0
        fftds[end-Ncut_low:end] .= 0.0
        ds = real.(ifft(fftds))
        ds = (dsmax / maximum(ds)) .* ds;
    end;

    distortions = permutedims(hcat(distortions...));

    # Define physical track
    trackprop = TrackProperties(track_gauge = 1.435, track_width = 0.11)
    Xspace = LinRange(5.0,20.0,60);

    using Plots
    h = 300;
    w = h * camera.opticalproperties.sensor_width / camera.opticalproperties.sensor_height
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

# ns = Int.(round.(LinRange(1,maxframes,140)))[1:35]
#     for i in eachindex(ns)
#         left_track  = [[x, -trackprop.track_gauge/2.0 + βs[ns[i]]*x^2, αs[ns[i]]*x^2] for x = Xspace]
#         right_track = [[x, trackprop.track_gauge/2.0 + βs[ns[i]]*x^2, αs[ns[i]]*x^2] for x = Xspace]
#
#         tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
#         camera = VideoCamera(camera_reference, Dict(choose_distortions .=> distortions[:,ns[i]]))
#
#         plot(tracks,camera, sleeper_displace = -0.09 * n, xlims = ulims, ylims = vlims, xguide = "", camera_grid = false, yguide = "",axis = false)
#         savefig("simulated-curve-tracks-$i")
#     end

    anim = @animate for n in Int.(round.(LinRange(1,maxframes,140)))
        left_track  = [[x, -trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]
        right_track = [[x, trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]

        tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
        camera = VideoCamera(camera_reference, Dict(choose_distortions .=> distortions[:,n]))

        plot(tracks,camera, sleeper_displace = -0.09 * n, xlims = ulims, ylims = vlims, xguide = "", yguide = "",axis = false)
    end

    # gif(anim, "../../images/videos/only-curvature.gif", fps = 7)
    gif(anim, "../../images/videos/simulate-short-trainview.gif", fps = 7)
    # gif(anim, "../../images/videos/simulate-trainview.gif", fps = 7)

# plot scatter from image recognition

    max_pixel_error = 1
    numberofpoints = 60

    # sample more closer to the camera
    len = 60
    mesh_size = LinRange(1e-5,0.2,len);
    Xspace = 1.0 .+ cumsum(cumsum(mesh_size))[1:end-3]
    filter!(x -> x < 40.0, Xspace)

    n = 10
    left_track  = [[x, -trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]
    right_track = [[x, trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]

    tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
    camera = VideoCamera(camera_reference, Dict(choose_distortions .=> distortions[:,n]))

    plot(tracks,camera, xlims = ulims, ylims = vlims, xguide = "", yguide = "")

    left_uvs = camera_image(camera, left_track);
    right_uvs = camera_image(camera, right_track);

    # sample only a subset evening across v
    Lvs = [uv[2] for uv in left_uvs];
    Rvs = [uv[2] for uv in right_uvs];

    Lvmax = maximum(Lvs); Lvmin = minimum(Lvs);
    Rvmax = maximum(Rvs); Rvmin = minimum(Rvs);

    vs = reverse(sort(rand(LinRange(Lvmin,Lvmax,5*numberofpoints),numberofpoints)));
    is = [findmin(abs.(v .- Lvs))[2] for v in vs];
    left_uvs = left_uvs[is]

    vs = reverse(sort(rand(LinRange(Rvmin,Rvmax,5*numberofpoints),numberofpoints)));
    is = [findmin(abs.(v .- Rvs))[2] for v in vs];
    right_uvs = right_uvs[is]

    # add error from image recognition
    left_uvs  = [uv +  max_pixel_error .* (rand(2) .- 0.5) for uv in left_uvs]
    right_uvs = [uv +  max_pixel_error .* (rand(2) .- 0.5) for uv in right_uvs]

    Lus = [uv[1] for uv in left_uvs]; Lvs = [uv[2] for uv in left_uvs];
    Rus = [uv[1] for uv in right_uvs]; Rvs = [uv[2] for uv in right_uvs];

    scatter!(Lus,Lvs,colour=:pink, lab="")
    scatter!(Rus,Rvs,colour=:pink, lab="")

    savefig("../../images/pink-image-sampling.pdf")
