using TrainView

using CSV, DataFrames
# using Statistics, LinearAlgebra

# input_uv_file = "data/output_results_centre_line.csv"

function track_to_cabin_movement(input_uv_file,output_file;
        cameraposition = [0.0, 0.6771, -2.1754],
        cameraψθφ = [0.0, -0.2038, -0.08219],
        trackprop = TrackProperties(track_gauge = 1.435 + 0.065),
        camera = VideoCamera(cameraposition;
            focal_length = 5.8e-3,
            pixelspermeter = 1 / 5.5e-6,
            ψθφ = cameraψθφ
        ),
        max_v::Int = 720, max_u::Int = 1280
    )

    uv_data = load_uv_data(input_uv_file; max_v = 720, max_u = 1280)

    if camera.xyz == [0.0,0.604,-2.165]
        println("You have not specified a camera setup, which you can do be passing the option 'camera = VideoCamera(position; ...)'. In this case the code will attempt to work out the camera setup from the data. Note the current values used for 'focal_length=$(camera.opticalproperties.focal_length)' and 'pixelspermeter=$(camera.opticalproperties.pixelspermeter)' which can not be inferred from the data.")

        camera = camera_calibration(uv_data;
            trackprop = trackprop,
            camera_initial_guess = camera
        )
    end

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
