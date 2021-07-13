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

include("../src/TrainView.jl")

trackprop = TrackProperties(track_gauge = 1.435 + 0.065)

cameraposition_reference = [0.0,0.6,-2.165];
ψθφ_ref = [0.0,-19.1,-7.28] .* (pi/180.0)

camera_reference = VideoCamera(cameraposition_reference;
    focal_length = 5.8e-3,
    pixelspermeter = 1 / 5.5e-6,
    ψθφ = ψθφ_ref
)

using CSV, DataFrames
using Statistics, LinearAlgebra
using Plots
gr(yflip = true)
GR.inline("png")

# args = ["../../data/output_results_centre_line.csv", "output.csv"]

file = "../../data/output_results_centre_line.csv";
# df = CSV.read(file, DataFrame);
df = CSV.File(file;

lines = open(file) do f
    [l for l in eachline(f)]
end;

header = lines[1];
lines = lines[2:end];

max_v = 720
max_u = 1280

uv_data = map(lines) do l
    data = parse.(Int,split(l,',')[2:end-1])

    Llen = data[1]
    Rlen = data[2]

    us = data[3:2:end] .- (max_u / 2.0);
    vs = data[4:2:end] .- (max_v / 2.0);

    Lu = us[1:Llen];
    Lv = vs[1:Llen];

    Ru = us[Llen+1:Rlen+Llen];
    Rv = vs[Llen+1:Rlen+Llen];

    return [Lu,Lv,Ru,Rv]
end;

using Plots
gr(yflip = true)

i = 100
Lu = uv_data[i][1];
Lv = uv_data[i][2];
Ru = uv_data[i][3];
Rv = uv_data[i][4];

Lu0 = left_track_image_u(camera_reference, trackprop, Lv);
Ru0 = right_track_image_u(camera_reference, trackprop, Rv);

plot(Lu,Lv, lab = "")
plot!(Ru,Rv, lab = "")

plot!(Lu0,Lv, lab = "")
plot!(Ru0,Rv, lab = "")

choose_distortions = [:Y,:Z,:θ,:φ];
choose_distortions = [:Y,:Z,:θ,:φ,:α,:β];

skip_distortion = repeat([0.0],length(choose_distortions))

distortions = map(uv_data) do uv

    left_uvs = map(uv[1],uv[2]) do u, v
        [u,v]
    end

    right_uvs = map(uv[3],uv[4]) do u, v
        [u,v]
    end

    distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
        choose_distortions = choose_distortions,
        iterations = 4)

    if abs(distortion[:Y]) > 0.1 + 0.5*abs(camera_reference.xyz[2]) || abs(distortion[:Z]) >= 0.5*abs(camera_reference.xyz[3])
        return skip_distortion
    else
        return [distortion[k] for k in choose_distortions]
    end
end;

filter!(d ->  norm(d - skip_distortion) > 0.0,distortions);

mean_distortion = mean(distortions);
std_distortion = std(distortions);

std_theshold = std_distortion * 0.4
calibrate_inds = [isempty(findall(abs.(mean_distortion - d) .> std_theshold)) for d in distortions];
count(calibrate_inds)

mean_distortion2 = mean(distortions[calibrate_inds]);
camera = VideoCamera(camera_reference, Dict(choose_distortions .=> mean_distortion2))

Lu2 = left_track_image_u(camera, trackprop, Lv);
Ru2 = right_track_image_u(camera, trackprop, Rv);

plot(Lu,Lv, lab = "")
plot!(Ru,Rv, lab = "")

plot!(Lu2,Lv,linestyle=:dash, lab = "")
plot!(Ru2,Rv,linestyle=:dash, lab = "")


# Create a gif
    n = 1;
    uv = uv_data[n]
    ulims = 1.5 .* (min(minimum(uv[1]),minimum(uv[3])),max(maximum(uv[1]),maximum(uv[3])))
    vlims = 1.5 .* (min(minimum(uv[2]),minimum(uv[4])),max(maximum(uv[2]),maximum(uv[4])))

    Lv = uv[2]; Rv = uv[4];
    Lu = left_track_image_u(camera, trackprop, Lv);
    Ru = right_track_image_u(camera, trackprop, Rv);

    plot(Lu,Lv,linestyle=:dash, lab = "", color = :blue)
    plot!(Ru,Rv,linestyle=:dash, lab = "", color = :blue)

    maxframes = length(uv_data)

    # anim = @animate for n in Int.(round.(LinRange(1,maxframes,600)))
    #     uv = uv_data[n];
    #
    #     plot(uv[1],uv[2], lab = "", color = :red )
    #     plot!(uv[3],uv[4], lab = "", color = :red )
    #
    #     plot!(Lu,Lv,linestyle=:dash, lab = "", color = :blue)
    #     plot!(Ru,Rv,linestyle=:dash, lab = "", color = :blue)
    #
    #     plot!(camera, xlims = ulims, ylims = vlims, xguide = "", yguide = "",axis = false)
    #
    # end
    #
    # # gif(anim, "../../images/videos/only-curvature.gif", fps = 7)
    # gif(anim, "../images/videos/compare-reference-to-track-center-line.gif", fps = 7)


# Calculate train car movement from frames
    choose_distortions = [:Y,:Z,:θT,:φT,:α,:β];

    distortions = map(uv_data) do uv

        left_uvs = map(uv[1],uv[2]) do u, v
            [u,v]
        end

        right_uvs = map(uv[3],uv[4]) do u, v
            [u,v]
        end

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera, trackprop;
            choose_distortions = choose_distortions,
            iterations = 1)

        return [distortion[k] for k in choose_distortions]
    end;

# create gif of distortions
    n = 1;
    uv = uv_data[n]
    ulims = 1.9 .* (min(minimum(uv[1]),minimum(uv[3])),max(maximum(uv[1]),maximum(uv[3])))
    vlims = 1.2 .* (min(minimum(uv[2]),minimum(uv[4])),max(maximum(uv[2]),maximum(uv[4])))

    Lv = uv[2]; Rv = uv[4];
    Lu = left_track_image_u(camera, trackprop, Lv);
    Ru = right_track_image_u(camera, trackprop, Rv);

    plot(Lu,Lv,linestyle=:dash, lab = "", color = :blue)
    plot!(Ru,Rv,linestyle=:dash, lab = "", color = :blue)

    plot!(camera, xlims = ulims, ylims = vlims, xguide = "", yguide = "",axis = false)

    Lu_ref = left_track_image_u(camera, trackprop, Lv);
    Ru_ref = right_track_image_u(camera, trackprop, Rv);

    ΔuL = left_track_Δu(camera, trackprop, Lv; choose_distortions=choose_distortions);
    ΔuR = right_track_Δu(camera, trackprop, Rv; choose_distortions=choose_distortions);

    maxframes = length(uv_data)

    anim = @animate for n in Int.(round.(LinRange(1,maxframes,500)))
        uv = uv_data[n];

        Lu = Lu_ref + ΔuL * distortions[n];
        Ru = Ru_ref + ΔuR * distortions[n];

        plot(uv[1],uv[2], lab = "", color = :red )
        plot!(uv[3],uv[4], lab = "recorded data", color = :red )

        plot!(Lu,Lv,linestyle=:dash, lab = "", color = :blue)
        plot!(Ru,Rv,linestyle=:dash, lab = "modeled track", color = :blue)

        p = plot!(camera, xlims = ulims, ylims = vlims,
            xguide = "", yguide = "", axis = nothing,
            xlab = "pixel u", ylab = "pixel v",
            legend = :topleft)
    end

    gif(anim, "../../images/videos/model-track-center-line.gif", fps = 7)

## gif that tracks distortions

    curve_distortions = [:α,:β]

    ΔuL = left_track_Δu(camera, trackprop, Lv; choose_distortions=curve_distortions);
    ΔuR = right_track_Δu(camera, trackprop, Rv; choose_distortions=curve_distortions);

    indαβ = [findfirst(s .== choose_distortions) for s in curve_distortions]
    indYZ = [findfirst(s .== choose_distortions) for s in [:Y,:Z]]
    indθT = [findfirst(s .== choose_distortions) for s in [:θT,:φT]]

    maxYZ = 1.5 .* mean([abs.(d[indYZ]) for d in distortions])
    maxθT = 5 .* mean([abs.(d[indθT]) for d in distortions])

    anim = @animate for n in Int.(round.(LinRange(1,maxframes,500)))
        uv = uv_data[n];

        Lu = Lu_ref + ΔuL * distortions[n][indαβ];
        Ru = Ru_ref + ΔuR * distortions[n][indαβ];

        plot(uv[1],uv[2], lab = "", color = :red )
        plot!(uv[3],uv[4], lab = "recorded data", color = :red )

        plot!(Lu,Lv,linestyle=:dash, lab = "", color = :blue)
        plot!(Ru,Rv,linestyle=:dash, lab = "model curvature", color = :blue)

        p = plot!(camera, xlims = ulims, ylims = vlims,
            xguide = "", yguide = "", axis = nothing,
            xlab = "pixel u", ylab = "pixel v",
            legend = :topleft)

        dYdZ = distortions[n][indYZ]
        dθdφ = distortions[n][indθT]

        pYZ = scatter([-dYdZ[1]],[-dYdZ[2]],
            label = "", title = "camera position",
            markersize = 6, markercolor = :green,
            xlims = (-maxYZ[1],maxYZ[1]),
            ylims = (-maxYZ[2],maxYZ[2]),
            axis = nothing,
            xlab = "y", ylab = "z"
        )
        ptheta = scatter([dθdφ[1]],[dθdφ[2]],
            label = "", title = "cabin orientation",
            markersize = 6, markercolor = :purple,
            xlims = (-maxθT[1],maxθT[1]),
            ylims = (-maxθT[2],maxθT[2]),
            axis = nothing,
            xlab = "θ", ylab = "φ"
        )

        l = @layout [
            a{0.6w,1.0h} [b{0.5h}
                     c{0.5h}  ]
        ]
        plot(p,pYZ,ptheta, layout = l)
    end

    gif(anim, "../../images/videos/track-distortions-track-center-line.gif", fps = 5)

    # p1 = plot(x, y) # Make a line plot
    # p2 = scatter(x, y) # Make a scatter plot
    # p3 = plot(x, y, xlabel = "This one is labelled", lw = 3, title = "Subtitle")
    # p4 = histogram(x, y) # Four histograms each with 10 points? Why not!
    # plot(p1, p2, p3, p4, layout = (2, 2), legend = false)
