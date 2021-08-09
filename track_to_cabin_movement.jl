using TrainView

using CSV, DataFrames
# using Statistics, LinearAlgebra

function track_to_cabin_movement(input_file,output_file)

    !isfile(input_file) && @error "there is no file: $input_file "

    println("Loading data file from:", input_file)
    println("I hope it's in the right format!")

    lines = open(input_file) do f
        [l for l in eachline(f)]
    end;

    header = lines[1];
    lines = lines[2:end];

    max_v = 720
    max_u = 1280

    trackprop = TrackProperties(track_gauge = 1.435 + 0.065)

    # from a previous calibration exercise
    camera_xyz = [0.0, 0.6771, -2.1754]
    camera_ψθφ = [0.0, -0.2038, -0.08219]

    camera = VideoCamera(camera_xyz;
        ψθφ = camera_ψθφ,
        focal_length = 5.8e-3,
        pixelspermeter = 1 / 5.5e-6
    )

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

    distortion_matrix = transpose(hcat(distortions...))

    df = DataFrame(distortion_matrix,choose_distortions)
    rename!(df,choose_distortions)

    CSV.write(output_file,df)

    println("Data saved as a CSV file in $(output_file)")

end

# Code below ensures that the above can be run from the terminal
if length(ARGS) > 1 && typeof(ARGS[1]) == String && typeof(ARGS[2]) == String
    track_to_cabin_movement(ARGS[1],ARGS[2])
end
