
# Initial guess at reference camera

# Richard Shenton email:
# Camera height: 2.065m
#
# Camera offset from centre line: 0.6m
# Pitch: 19.16 degrees down
# Yaw: 7.28 degrees to the left
# Roll: Assumed to be zero

"""
    calibrated_camera(input_uv_file::String;
        sensor_width::Int = 960, sensor_height::Int = 540,
        kws...
    )

Returns a calibrated camera using the data from the file input_uv_file. This data has a very special format that can be seen from the code in this function.
"""
function calibrated_camera(input_uv_file::String;
        sensor_width::Int = 1000, sensor_height::Int = 600,
        kws...
    )

    sensor_width == 1000 && sensor_height == 600 && @warn "It appears you have not specified the maximum (u,v) value for your images. Will use sensor_width = $sensor_width and sensor_height = $sensor_height."

    # NOTE: in the future I should load and save uv_data without centering it.
    frames, uv_data = load_uv_data(input_uv_file; sensor_width = sensor_width, sensor_height = sensor_height)

    return calibrated_camera(uv_data; sensor_width = sensor_width, sensor_height = sensor_height, kws...)
end

"""
    calibrated_camera(uv_data;
        camera_xyz = [0.0,0.604,-2.165],
        ψθφ = [0.0,-19.1,-7.28] .* (pi/180.0),
        trackprop = TrackProperties(track_gauge = 1.435 + 0.065)
    )

Returns a calibrated camera where each 'uv_data[i]' contains the uv points from one image. For each image, 'uv_data[i] = [Lu,Lv,Ru,Rv]' where 'Lu' is a vector with all the u values for the left track, while 'Rv' is a vector of all v values on the right track. Note that u and v are given relative to the centre of the image, and not relative to the top left corner.
"""
function calibrated_camera(uv_data::Vector{Vector{V}};
        trackprop = TrackProperties(track_gauge = 1.435 + 0.065),
        camera_xyz::Vector = [0.0,0.0,-2.2],
        camera_initial_guess = nothing,
        kws...
    ) where V <: AbstractVector


    if camera_initial_guess == nothing && camera_xyz == [0.0,0.0,-2.2]
        println("You have not specified an initial guess for the camera position. Will use some default values")
    end

    trackprop.track_gauge == 1.435 + 0.065 && println("It appears you have not specified the track gauge. Will use the default value $(trackprop.track_gauge)")

    if camera_initial_guess == nothing
        camera_initial_guess = VideoCamera(camera_xyz; kws...)
        # camera_initial_guess = VideoCamera(camera_xyz; ψθφ = [0.0,0.0,0.0],
        # sensor_width = 960, sensor_height = 540)
    end

    choose_distortions = [:Y,:Z,:θ,:φ,:α,:β];
    skip_distortion = repeat([0.0],length(choose_distortions))

    distortions = map(uv_data) do uv

        # NOTE: this assumes u and v are described in terms of the centre of the image.
        left_uvs = map(uv[1],uv[2]) do u, v
            [u,v]
        end

        right_uvs = map(uv[3],uv[4]) do u, v
            [u,v]
        end

        try
            distortion, fit = rail_uvs_to_distortion(left_uvs, right_uvs, camera_initial_guess, trackprop;
                choose_distortions = choose_distortions,
                iterations = 4
            )
            if abs(distortion[:Y]) > 1.0 + 2*abs(camera_initial_guess.xyz[2]) || abs(distortion[:Z]) >= 1.0 + 2*abs(camera_initial_guess.xyz[3])
                return skip_distortion
            else
                return [distortion[k] for k in choose_distortions]
            end
        catch
            return skip_distortion
        end
    end;

    filter!(d ->  norm(d - skip_distortion) > 0.0,distortions);

    mean_distortion = mean(distortions);
    std_distortion = std(distortions);

    std_theshold = std_distortion * 0.4
    calibrate_inds = [isempty(findall(abs.(mean_distortion - d) .> std_theshold)) for d in distortions];
    count(calibrate_inds)

    mean_distortion2 = mean(distortions[calibrate_inds]);
    calibrated_camera = VideoCamera(camera_initial_guess, Dict(choose_distortions .=> mean_distortion2))

    return calibrated_camera
end
