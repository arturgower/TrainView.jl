using TrainView

using CSV, DataFrames
# using Statistics, LinearAlgebra
#
# input_uv_file = "data/output_results_centre_line.csv"

function track_to_cabin_movement(input_uv_file,output_file;
        setup_output_file::String = "empty000",
        camera_xyz = [0.0, 0.5, -2.2],
        trackprop = TrackProperties(track_gauge = 1.435 + 0.065),
        sensor_width = 960,
        sensor_height = 540,
        camera = VideoCamera(camera_xyz;
            sensor_width = sensor_width,
            sensor_height = sensor_height
        ),
    )

        uv_data = load_uv_data(input_uv_file;
            sensor_width = camera.opticalproperties.sensor_width,
            sensor_height = camera.opticalproperties.sensor_height
        );

        if camera.xyz == [0.0,0.5,-2.2]
            println("You have not specified a camera setup, which you can do be passing the option 'camera = VideoCamera(position; ...)'. In this case the code will attempt to work out the camera setup from the data. Note the current values used for 'focal_length=$(camera.opticalproperties.focal_length)' and 'pixelspermeter=$(camera.opticalproperties.pixelspermeter)' which can not be inferred from the data.")

            camera = camera_calibration(uv_data;
                trackprop = trackprop,
                camera_initial_guess = camera
            )
        end

        if setup_output_file != "empty000"
            dcam = Dict(camera)
            dtrack = Dict(trackprop)

            CSV.write(setup_output_file,DataFrame(merge(dcam,dtrack)))

            # df_cam = DataFrame(CSV.File("camera_test.csv"))
            # VideoCamera(df_cam)
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
if 1 < length(ARGS) < 2 && typeof(ARGS[1]) == String && typeof(ARGS[2]) == String
    track_to_cabin_movement(ARGS[1],ARGS[2])
end

if length(ARGS) > 2 && typeof(ARGS[1]) == String && typeof(ARGS[2]) == String && typeof(ARGS[3]) == String
    track_to_cabin_movement(ARGS[1],ARGS[2]; setup_output_file = ARGS[3])
end
