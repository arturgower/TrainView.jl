include("src/TrainView.jl")

using CSV, DataFrames
using Statistics, LinearAlgebra

file = "../data/rail_detection_results_20210127.csv";
df = CSV.read(file, DataFrame);

Lu1 = df." Left_Rail_Bottom_X";
Lv1 = df." Left_Rail_Bottom_Y";
Lu2 = df." Left_Rail_Top_X";
Lv2 = df." Left_Rail_Top_Y";

Ru1 = df." Right_Rail_Bottom_X";
Rv1 = df." Right_Rail_Bottom_Y";
Ru2 = df." Right_Rail_Top_X";
Rv2 = df." Right_Rail_Top_Y";


# max_v = max(maximum(Lv1),maximum(Rv1))
max_v = 720
vs = [Lv1, Lv2, Rv1, Rv2];
for v in vs
    v[1:end] = (max_v / 2.0) .- v
end

# max_u = max(maximum(Lu2),maximum(Ru2))
max_u = 1280
us = [Lu1, Lu2, Ru1, Ru2];
for v in us
    v[1:end] = v .- (max_u / 2.0)
end

Lu = LinRange(mean(Lu1),mean(Lu2),20);
Lv = LinRange(mean(Lv1),mean(Lv2),20);
Ru = LinRange(mean(Ru1),mean(Ru2),20);
Rv = LinRange(mean(Rv1),mean(Rv2),20);

left_uvs =  [[Lu[i],Lv[i]] for i in eachindex(Lu)];
right_uvs = [[Ru[i],Rv[i]] for i in eachindex(Ru)];


# Initial guess at reference camera

# Richard Shenton email:
# Camera height: 2.065m
#
# Camera offset from centre line: 0.6m
# Pitch: 19.16 degrees down
# Yaw: 7.28 degrees to the left
# Roll: Assumed to be zero

trackprop = TrackProperties(track_gauge = 1.435 + 0.065)

cameraposition_reference = [0.0,0.604,2.165];
cameraposition_reference = [0.0,0.604,2.165];
ψθφ_ref = [0.0,19.16,-7.28] .* (pi/180.0)
ψθφ_ref = [1.5,11.0,-4.5] .* (pi/180.0)

# cameraposition_reference = [0.0,-0.604,2.065];
# ψθφ_ref = [0.0,0.0,0.0] .* (pi/180.0)
# ψθφ_ref = [0.0,11.0,-13.0] .* (pi/180.0)
# ψθφ_ref = [0.0,10.5,-16.0] .* (pi/180.0)

camera_reference = VideoCamera(cameraposition_reference;
    focal_length = 5.8e-3,
    pixelspermeter = 1 / 5.5e-6,
    ψθφ = ψθφ_ref
)

uLs = left_track_image_u(camera_reference, trackprop, Lv);
uRs = right_track_image_u(camera_reference, trackprop, Rv);

using Plots
plot(Lu,Lv, lab = "")
plot!(Ru,Rv, lab = "")

plot!(uLs,Lv,linestyle=:dash, lab = "")
plot!(uRs,Rv,linestyle=:dash, lab = "")


using Optim

function calibration_objective(v::Vector)
    cameraposition = [0.0,v[1],v[2]];
    ψθφ = [v[3],v[4],v[5]] .* (pi/180.0)

    camera = VideoCamera(cameraposition;
        focal_length = 5.8e-3,
        pixelspermeter = 1 / 5.5e-6,
        ψθφ = ψθφ
    )

    uLs = left_track_image_u(camera, trackprop, Lv);
    uRs = right_track_image_u(camera, trackprop, Rv);

    scale = 10.0;
    # Y Z ψ θ φ
    mins = [-1.0,1.0,-3.0,-1.0,-15.0]
    maxs = [1.0 ,2.6, 3.0,50.0,15.0]
    constraints = map(1:length(v)) do j
        (v[j] > maxs[j]) * (exp(scale*(v[j]-maxs[j])^2) - 1.0) + (v[j] < mins[j]) * (exp(scale*(v[j] - mins[j])^2) - 1.0)
    end

    return sum(constraints) + sum(abs2.(uLs - Lu)) / sum(abs2.(Lu) + abs2.(Lv)) + sum(abs2.(uRs - Ru)) / sum(abs2.(Ru) + abs2.(Rv))
end

v = [cameraposition_reference[2:3]; ψθφ_ref[1:3] .* (180.0 / pi)];
calibration_objective(v)

tol = 1e-5
res = optimize(calibration_objective, v, Optim.Options(x_tol=tol))
v = res.minimizer
calibration_objective(v)

cameraposition_reference = [0.0,v[1],v[2]]
ψθφ_ref = [0.0,v[3],v[4]] .* (pi/180.0)

camera_reference = VideoCamera(cameraposition_reference;
    focal_length = 5.8e-3,
    pixelspermeter = 1 / 5.5e-6,
    ψθφ = ψθφ_ref
)

uLs = left_track_image_u(camera_reference, trackprop, Lv);
uRs = right_track_image_u(camera_reference, trackprop, Rv);

plot(Lu,Lv, lab = "")
plot!(Ru,Rv, lab = "")

plot!(uLs,Lv,linestyle=:dash, lab = "")
plot!(uRs,Rv,linestyle=:dash, lab = "")


v = [0.604,2.065,11.16,-4.4];
lower = [0.1, 1.9,0.0,-15.0]
upper = [1.0, 2.8,20.0,15.0]
inner_optimizer = GradientDescent()
res = optimize(calibration_objective, lower, upper, v, Fminbox(inner_optimizer))

v = res.minimizer

cameraposition_reference = [0.0,v[1],v[2]];
ψθφ_ref = [0.0,v[3],v[4]] .* (pi/180.0);
# ψθφ_ref = [ mod(a,2pi) for a in ψθφ_ref]

camera_reference = VideoCamera(cameraposition_reference;
    focal_length = 5.8e-3,
    pixelspermeter = 1 / 5.5e-6,
    ψθφ = ψθφ_ref
)

uLs = left_track_image_u(camera_reference, trackprop, Lv);
uRs = right_track_image_u(camera_reference, trackprop, Rv);

plot(Lu,Lv, lab = "")
plot!(Ru,Rv, lab = "")

plot!(uLs,Lv,linestyle=:dash, lab = "")
plot!(uRs,Rv,linestyle=:dash, lab = "")

distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
    choose_distortions = [:Y,:Z,:θ,:φ],
    # choose_distortions = [:Y,:Z,:θ,:φ,:α,:β],
    iterations = 1)

camera = VideoCamera(camera_reference,distortion)

uLs2 = left_track_image_u(camera, trackprop, Lv);
uRs2 = right_track_image_u(camera, trackprop, Rv);

plot!(uLs2,Lv,linestyle=:dash, lab = "")
plot!(uRs2,Rv,linestyle=:dash, lab = "")
