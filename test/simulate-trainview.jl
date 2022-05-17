using TrainView
using FFTW

maxframes = 400

max_curvature = 5e-4
# max_curvature = 0.0

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
    βs = [max_curvature * cos(2n * 2pi / maxframes)  for n in 1:maxframes];
    αs = [max_curvature * cos(n * 2pi / maxframes)  for n in 1:maxframes];

# displacements relative to the track
    choose_distortions = [:Y,:Z,:ψ,:θ,:φ];
    max_distortions = [[0.05,0.06]; pi/180 .* [2.0,2.0,0.0]]
    max_distortions = [[0.02,0.03]; pi/180 .* [1.0,1.0,0.0]]

    Nsmooth = Int(round(maxframes / 20))
    Ncut_high = Int(round(maxframes / 35))
    Ncut_low = Int(round(maxframes / 130))

    δs = map(max_distortions) do dsmax
        ds = 2 .* rand(maxframes+Nsmooth) .- 1.0
        fftds = fft(ds)
        fftds[Ncut_high:end-Ncut_high] .= 0.0
        fftds[1:Ncut_low] .= 0.0
        fftds[end-Ncut_low:end] .= 0.0
        ds = real.(ifft(fftds))
        ds = (dsmax / maximum(ds)) .* ds;
    end;

    δs = permutedims(hcat(δs...));

# Define physical track
    trackprop = TrackProperties(track_gauge = 1.435, track_width = 0.11)
    Xspace = LinRange(8.0,20.0,60);

# Calculate all track uvs from all frames
    max_pixel_error = 4
    max_pixel_error = 0
    numberofpoints = 50

    ns = Int.(round.(LinRange(1,maxframes,140)));
    ns = ns[1:100]
    using DataFrames, CSV

    image_δs = map(ns) do n
        left_track  = [[x, -trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]
        right_track = [[x, trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace]

        camera = VideoCamera(camera_reference, Dict(choose_distortions .=> δs[:,n]))

        left_uvs = camera_image(camera, left_track);
        right_uvs = camera_image(camera, right_track);

        # sample only a subset evening across v
        Lvs = [uv[2] for uv in left_uvs];
        Rvs = [uv[2] for uv in right_uvs];

        Lvmax = 0.8*maximum(Lvs); Lvmin = minimum(Lvs);
        Rvmax = 0.8*maximum(Rvs); Rvmin = minimum(Rvs);

        vs = reverse(sort(rand(LinRange(Lvmin,Lvmax,5*numberofpoints),numberofpoints)));
        is = [findmin(abs.(v .- Lvs))[2] for v in vs];
        left_uvs = left_uvs[is];

        vs = reverse(sort(rand(LinRange(Rvmin,Rvmax,5*numberofpoints),numberofpoints)));
        is = [findmin(abs.(v .- Rvs))[2] for v in vs];
        right_uvs = right_uvs[is];

        # add error from image recognition
        left_uvs  = [uv +  max_pixel_error .* (rand(2) .- 0.5) for uv in left_uvs];
        right_uvs = [uv +  max_pixel_error .* (rand(2) .- 0.5) for uv in right_uvs];

        # df = DataFrame(
        #       left_u  = [uv[1] for uv in left_uvs],
        #       left_v  = [uv[2] for uv in left_uvs],
        #       right_u = [uv[1] for uv in right_uvs],
        #       right_v = [uv[2] for uv in right_uvs]
        # )
        #
        # CSV.write("straight-track-points-on-image-$(findfirst(ns .== n)).csv", df)

        image_distortion, fits = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
            # choose_distortions = [:Y,:Z,:ψ,:θ,:α,:β],
            choose_distortions = [:Y,:Z,:ψ,:θ],
            iterations = 6
        );
        d1 = [image_distortion[d] for d in choose_distortions];
        # d1 = [[image_distortion[d] for d in choose_distortions]; [image_distortion[:α],image_distortion[:β]]];
        # d2 = [δs[:,n]; [αs[n], βs[n]]];
        #
        # abs.(d1-d2)
    end;

    image_δs = hcat(image_δs...)

    errors = map(eachindex(ns)) do n
        ds = δs[:,ns[n]]
        abs.(image_δs[:,n] - ds)
    end;

    # errors = map(eachindex(ns)) do n
    #     ds = [δs[:,ns[n]]; [αs[ns[n]], βs[ns[n]]]]
    #     abs.(image_δs[:,n] - ds)
    # end;

    [:Y,:Z,:θ,:ψ,:α,:β]
    max_amps = max_distortions;
    # max_amps = [max_distortions; [max_curvature,max_curvature]];
    mean(errors) ./ max_amps
    maximum(hcat(errors...), dims=2) ./ max_amps

using Plots

plot([δs[2,ns], image_δs[2,:]], lab = ["dZ" "predict dZ"],
    xlab = "frames", ylab = "amplitude", title="Without considering curvature"
)
plot!(αs[ns] * 100, lab = "Vertical curvature")
plot!(βs[ns] * 100, lab = "Horizontal curvature")
# savefig("../../images/recover-dz-with-curve.pdf")
savefig("../../images/recover-dz-without-curve.pdf")

plot([δs[1,ns], image_δs[1,:]], lab = ["dY" "predict dY"],
    xlab = "frames", ylab = "amplitude", title="Without considering curvature"
)
plot!(αs[ns] * 100, lab = "Vertical curvature")
plot!(βs[ns] * 100, lab = "Horizontal curvature")
savefig("../../images/recover-dy-without-curve.pdf")
# savefig("../../images/recover-dz-with-curve.pdf")

# plot([αs[ns], image_δs[6,:]])
# plot([βs[ns], image_δs[7,:]])

    # df = DataFrame(
    #       camera_u_centre = 0.0,
    #       camera_v_centre = 0.0,
    #       camera_X = cameraposition_reference[1],
    #       camera_Y = cameraposition_reference[2],
    #       camera_Z = cameraposition_reference[3],
    #       roll_ψ_rad = ψθφ_ref[1],
    #       pitch_θ_rad = ψθφ_ref[2],
    #       yaw_φ_rad = ψθφ_ref[3],
    #       track_gauge = trackprop.track_gauge,
    #       track_width = trackprop.track_width,
    #       sensor_height_pixels = camera_reference.opticalproperties.sensor_height,
    #       sensor_width_pixels = camera_reference.opticalproperties.sensor_width,
    #       focal_length_meters = camera_reference.opticalproperties.focal_length,
    #       pixels_per_meter = camera_reference.opticalproperties.pixelspermeter,
    # )
    # CSV.write("meta-data.csv", df)

    # Create a gif
        left_track  = [[x, -trackprop.track_gauge/2.0,0.0] for x = Xspace]
        right_track = [[x, trackprop.track_gauge/2.0,0.0] for x = Xspace]
        Luvs = camera_image(camera_reference, left_track);
        Ruvs = camera_image(camera_reference, right_track);
        Lus = [uv[1] for uv in Luvs];
        Lvs = [uv[2] for uv in Luvs];
        Rus = [uv[1] for uv in Ruvs];
        Rvs = [uv[2] for uv in Ruvs];
        ulims = 1.5 .* (min(minimum(Rus),minimum(Lus)),max(maximum(Rus),maximum(Lus)))
        vlims = 1.2 .* (min(minimum(Rvs),minimum(Lvs)),max(maximum(Rvs),maximum(Lvs)))

    anim = @animate for n in ns
        left_track  = [[x, -trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace];
        right_track = [[x, trackprop.track_gauge/2.0 + βs[n]*x^2, αs[n]*x^2] for x = Xspace];

        tracks = TracksAhead(left_track,right_track; trackproperties = trackprop)
        camera = VideoCamera(camera_reference, Dict(choose_distortions .=> δs[:,n]))

        plot(tracks,camera, sleeper_displace = -0.09 * n, xlims = ulims, ylims = vlims, xguide = "", yguide = "",axis = false)
    end

    gif(anim, "../../images/videos/simulate-with-curavture.gif", fps = 7)
