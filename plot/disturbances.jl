include("../src/TrainView.jl")

using Statistics, LinearAlgebra
using Plots

height = 250
gr(size=(1.61 * height, height), yflip = true)

trackproperties = TrackProperties(track_gauge = 1.435)
trackproperties2 = TrackProperties(track_gauge = 1.435 + 0.12)

ψθφ_ref = [1.0,-15.0,-5.0] .* pi / 180;
cameraposition = [0.0,0.4,-1.14];

camera = VideoCamera(cameraposition;
    focal_length = 5.8e-3,
    pixelspermeter = 1 / 5.5e-6,
    ψθφ = ψθφ_ref
)
vs = LinRange(0.0, camera.opticalproperties.sensor_height / 3.5, 40)[2:end];

choose_distortions = [:Y,:Z,:ψ,:θ,:φ,:α,:β];
choose_distortions = [:Y,:Z,:ψT];

uL = left_track_image_u(camera, trackproperties, vs);
uR = right_track_image_u(camera, trackproperties, vs);

uL2 = left_track_image_u(camera, trackproperties2, vs);
uR2 = right_track_image_u(camera, trackproperties2, vs);

ΔuL = left_track_Δu(camera, trackproperties, vs; choose_distortions = choose_distortions);
ΔuR = right_track_Δu(camera, trackproperties, vs; choose_distortions = choose_distortions);

ΔuL2 = left_track_Δu(camera, trackproperties2, vs; choose_distortions = choose_distortions);
ΔuR2 = right_track_Δu(camera, trackproperties2, vs; choose_distortions = choose_distortions);

# Calculate how a grid on the track floor looks like in the camera image
    v2X = v_to_X(camera, trackproperties.track_gauge / 2.0);

    Ymax = 0.8 * trackproperties.track_gauge;
    Xmin =  minimum(v2X.(vs));
    Xmax =  maximum(v2X.(vs));

map(choose_distortions) do d
    i = findfirst(choose_distortions .== d);
    δs = zeros(length(choose_distortions));
    δs[i] = 0.1;

    plot(camera; Xmin = Xmin, Xmax = Xmax, Ymax = Ymax)

    plot!(Shape([uL;reverse(uL2)], [vs;reverse(vs)]),
        color = :red, lab = "",
        grid = false,
        legend = :bottom,
        title = "$(choose_distortions[i]) disturbance",
        # title = "reference image",
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
    # savefig("../../images/$(choose_distortions[i])-disturbance-flat.pdf")
    # savefig("../../images/reference-tracks.pdf")
end
