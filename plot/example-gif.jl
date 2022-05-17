using TrainView
using LinearAlgebra, Statistics
using FFTW

include("animate.jl")

maxframes = 400
max_curvature = 1e-3

trackprop = TrackProperties(track_gauge = 1.435, track_width = 0.11)


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

    distortions = hcat(distortions...)[1:maxframes,:];
    df_distortions = DataFrame(hcat(distortions,αs,βs),[choose_distortions; :α; :β]);

    anim = animate(camera_reference, trackprop, df_distortions);

    # gif(anim, "../../images/videos/only-curvature.gif", fps = 7)
    gif(anim, "images/simulate-short-trainview.gif", fps = 7)
    # gif(anim, "../../images/videos/simulate-trainview.gif", fps = 7)

    # # plot scatter from image recognition
    #
    #     max_pixel_error = 1
    #     numberofpoints = 60
    #
    #     # sample more closer to the camera
    #     len = 60
    #     mesh_size = LinRange(1e-5,0.2,len);
    #     Xspace = 1.0 .+ cumsum(cumsum(mesh_size))[1:end-3]
    #     filter!(x -> x < 40.0, Xspace)
    #
    #     n = 10
    #     left_track  = [[x, -trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]
    #     right_track = [[x, trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]
    #
    #     tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
    #     camera = VideoCamera(camera_reference, Dict(choose_distortions .=> distortions[:,n]))
    #
    #     plot(tracks,camera, xlims = ulims, ylims = vlims, xguide = "", yguide = "")
    #
    #     left_uvs = camera_image(camera, left_track);
    #     right_uvs = camera_image(camera, right_track);
    #
    #     # sample only a subset evening across v
    #     Lvs = [uv[2] for uv in left_uvs];
    #     Rvs = [uv[2] for uv in right_uvs];
    #
    #     Lvmax = maximum(Lvs); Lvmin = minimum(Lvs);
    #     Rvmax = maximum(Rvs); Rvmin = minimum(Rvs);
    #
    #     vs = reverse(sort(rand(LinRange(Lvmin,Lvmax,5*numberofpoints),numberofpoints)));
    #     is = [findmin(abs.(v .- Lvs))[2] for v in vs];
    #     left_uvs = left_uvs[is]
    #
    #     vs = reverse(sort(rand(LinRange(Rvmin,Rvmax,5*numberofpoints),numberofpoints)));
    #     is = [findmin(abs.(v .- Rvs))[2] for v in vs];
    #     right_uvs = right_uvs[is]
    #
    #     # add error from image recognition
    #     left_uvs  = [uv +  max_pixel_error .* (rand(2) .- 0.5) for uv in left_uvs]
    #     right_uvs = [uv +  max_pixel_error .* (rand(2) .- 0.5) for uv in right_uvs]
    #
    #     Lus = [uv[1] for uv in left_uvs]; Lvs = [uv[2] for uv in left_uvs];
    #     Rus = [uv[1] for uv in right_uvs]; Rvs = [uv[2] for uv in right_uvs];
    #
    #     scatter!(Lus,Lvs,colour=:pink, lab="")
    #     scatter!(Rus,Rvs,colour=:pink, lab="")
    #
    #     savefig("../../images/pink-image-sampling.pdf")
