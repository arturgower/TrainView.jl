## Calibrate camera
    # Initial guess at reference camera

    # Richard Shenton email:
    # Camera height: 2.065m
    #
    # Camera offset from centre line: 0.6m
    # Pitch: 19.16 degrees down
    # Yaw: 7.28 degrees to the left
    # Roll: Assumed to be zero

    # The camera frame rate is 25fps for this data. Regarding train details, there are some details here https://en.wikipedia.org/wiki/British_Rail_Class_357 .
    #
    # It looks to me that the carriage with the cab (seems to be called DMOS) is 20.75(L) x 2.8 (W) x 3.78(H) and weighs 40.7 t.

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
    v[1:end] = v .- (max_v / 2.0)
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

    trackprop = TrackProperties(track_gauge = 1.435 + 0.065)

    cameraposition_reference = [0.0,0.6,-2.165];
    ψθφ_ref = [0.0,-19.1,-7.28] .* (pi/180.0)

    camera_reference = VideoCamera(cameraposition_reference;
        focal_length = 5.8e-3,
        # focal_length = 5.8e-3,
        pixelspermeter = 1 / 5.5e-6,
        ψθφ = ψθφ_ref
    )

    uLs = left_track_image_u(camera_reference, trackprop, Lv);
    uRs = right_track_image_u(camera_reference, trackprop, Rv);

    distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
        choose_distortions = [:Y,:Z,:θ,:φ],
        # choose_distortions = [:Y,:Z,:f,:θ,:φ,:ψ,:α,:β],
        iterations = 6)

    camera = VideoCamera(camera_reference,distortion)

    uLs2 = left_track_image_u(camera, trackprop, Lv);
    uRs2 = right_track_image_u(camera, trackprop, Rv);

    using Plots
    gr(yflip = true)

    plot(Lu,Lv, lab = "")
    plot!(Ru,Rv, lab = "")

    plot!(uLs2,Lv,linestyle=:dash, lab = "")
    plot!(uRs2,Rv,linestyle=:dash, lab = "")

## Analise journey
    choose_distortions = [:Y,:Z,:θ,:ψ];
    # choose_distortions = [:Y,:Z,:θ,:φ,:ψ,:α,:β]

    distortions = map(eachindex(Lu1)) do j
        Lu = LinRange(Lu1[j],Lu2[j],20);
        Lv = LinRange(Lv1[j],Lv2[j],20);
        Ru = LinRange(Ru1[j],Ru2[j],20);
        Rv = LinRange(Rv1[j],Rv2[j],20);

        left_uvs =  [[Lu[i],Lv[i]] for i in eachindex(Lu)];
        right_uvs = [[Ru[i],Rv[i]] for i in eachindex(Ru)];

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera, trackprop;
            choose_distortions = choose_distortions,
            iterations = 1
        );
        return [distortion[d] for d in choose_distortions]
    end

    data = transpose(hcat(distortions...))

    dict = Dict(choose_distortions[j] => data[:,j] for j in eachindex(choose_distortions))

    df = DataFrame(dict);

    moving_average(vs,n) = [sum(@view vs[i:(i+n-1)])/n for i in 1:(length(vs)-(n-1))]

    ## Plotting using the @df macro specifying colum names as symbol:
    using StatsPlots
    n = 15;
    n = 25;
    fps = 25;
    time = (1:size(data,1)) ./ fps
    df.time = time;

    @df df plot(moving_average(:time,n), [moving_average(:Y,n),moving_average(:Z,n)], labels = ["Horizontal" "Vertical"], xlab = "seconds")

    @df df plot(:time,[:Y,:Z], labels = ["Horizontal" "Vertical"], xlab = "seconds")

    @df df plot(moving_average(:time,n), [moving_average(:θ,n) * 180/π, moving_average(:ψ,n) * 180/π], labels = ["Pitch" "Roll"], xlab = "seconds", ylab = "Degree")
