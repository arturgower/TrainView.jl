include("../src/TrainView.jl")

using Statistics, LinearAlgebra
using Plots

height = 250
gr(size=(1.61 * height, height), yflip = true)

trackproperties = TrackProperties(track_gauge = 1.435)
trackproperties2 = TrackProperties(track_gauge = 1.435 + 0.12)

ψθφ_ref = [1.0,15.0,5.0] .* pi / 180;
cameraposition = [0.0,0.4,1.14];

camera = VideoCamera(cameraposition;
    focal_length = 5.8e-3,
    pixelspermeter = 1 / 5.5e-6,
    ψθφ = ψθφ_ref
)
vs = LinRange(-camera.opticalproperties.sensor_height / 3.5, 0.0, 40);

choose_distortions = [:Y,:Z,:ψ,:θ,:φ,:α,:β];

uL = left_track_image_u(camera, trackproperties, vs);
uR = right_track_image_u(camera, trackproperties, vs);

uL2 = left_track_image_u(camera, trackproperties2, vs);
uR2 = right_track_image_u(camera, trackproperties2, vs);

ΔuL = left_track_Δu(camera, trackproperties, vs; choose_distortions = choose_distortions);
ΔuR = right_track_Δu(camera, trackproperties, vs; choose_distortions = choose_distortions);

ΔuL2 = left_track_Δu(camera, trackproperties2, vs; choose_distortions = choose_distortions);
ΔuR2 = right_track_Δu(camera, trackproperties2, vs; choose_distortions = choose_distortions);

# Calculate how a grid on the track floor looks like in the camera image
    hlines = [
        [[x, y, 0.0] for y in LinRange(-1.5,1.5,10)]
    for x = 1.0:0.5:8.0];
    vlines = [
        [[x, y, 0.0] for x in LinRange(1.0,10.0,20)]
    for y in -1.5:0.5:1.5];

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
    function plotgrid()
        plot()
        [plot!(cam..., color = :black, lab = "", linealpha = 0.3, linewidth = 0.1) for cam in cam_hlines]
        [plot!(cam..., color = :black, lab = "", linealpha = 0.3) for cam in cam_vlines]
    end

map(choose_distortions) do d
    i = findfirst(choose_distortions .== d);
    δs = zeros(length(choose_distortions));
    δs[i] = 0.1;

    plotgrid()

    plot!(Shape([uL;reverse(uL2)], [vs;reverse(vs)]),
        color = :red, lab = "",
        grid = false,
        legend = :bottom,
        title = "$(choose_distortions[i]) disturbance",
        xlab = "u", ylab = "v"
        )
    plot!(Shape([uR;reverse(uR2)], [vs;reverse(vs)]),color = :red, lab = "", legend = :bottom)

    plot!(Shape([uL + ΔuL * δs;reverse(uL2 + ΔuL2 * δs)], [vs;reverse(vs)]),
        color = :blue, fillalpha = 0.4,
        lab = ""
    )
    plot!(Shape([uR + ΔuR * δs;reverse(uR2 + ΔuR2 * δs)], [vs;reverse(vs)]),
        color = :blue, fillalpha = 0.4,
        lab = ""
    )
    savefig("../../images/$(choose_distortions[i])-disturbance.pdf")
end
