
# Initial guess at reference camera

# Richard Shenton email:
# Camera height: 2.065m
#
# Camera offset from centre line: 0.6m
# Pitch: 19.16 degrees down
# Yaw: 7.28 degrees to the left
# Roll: Assumed to be zero

"""
    camera_calibration(input_uv_file::String;
        max_v::Int = 720, max_u::Int = 1280,
        kws...
    )

Returns a calibrated camera using the data from the file input_uv_file. This data has a very special format that can be seen from the code in this function.
"""
function camera_calibration(input_uv_file::String;
        max_v::Int = 720, max_u::Int = 1280,
        kws...
    )

    max_v == 720 && max_u == 1280 && println("It appears you have not specified the maximum (u,v) value for your images. Will use max_u = $max_u and max_v = $max_v.")

    uv_data = load_uv_data(input_uv_file; max_v = 720, max_u = 1280)

    return camera_calibration(uv_data; kws...)
end

"""
    camera_calibration(uv_data;
        cameraposition_reference = [0.0,0.604,-2.165],
        ψθφ_ref = [0.0,-19.1,-7.28] .* (pi/180.0),
        trackprop = TrackProperties(track_gauge = 1.435 + 0.065)
    )

Returns a calibrated camera where each 'uv_data[i]' contains the uv points from one image. For each image, 'uv_data[i] = [Lu,Lv,Ru,Rv]' where 'Lu' is a vector with all the u values for the left track, while 'Rv' is a vector of all v values on the right track. Note that u and v are given relative to the centre of the image, and not relative to the top left corner.
"""
function camera_calibration(uv_data::Vector{Vector{V}};
        trackprop = TrackProperties(track_gauge = 1.435 + 0.065),
        cameraposition_reference = [0.0,0.604,-2.165],
        ψθφ_ref = [0.0,-19.1,-7.28] .* (pi/180.0),
        camera_initial_guess = VideoCamera(cameraposition_reference;
            focal_length = 5.8e-3,
            pixelspermeter = 1 / 5.5e-6,
            ψθφ = ψθφ_ref
        )
    ) where V <: AbstractVector

    camera_initial_guess.xyz == [0.0,0.604,-2.165] && println("You have not specified an initial guess for the camera position. Will use some default values")
    trackprop.track_gauge == 1.435 + 0.065 && println("It appears you have not specified the track gauge. Will use the default value $(trackprop.track_gauge)")

    choose_distortions = [:Y,:Z,:θ,:φ,:α,:β];
    skip_distortion = repeat([0.0],length(choose_distortions))

    distortions = map(uv_data) do uv

        left_uvs = map(uv[1],uv[2]) do u, v
            [u,v]
        end

        right_uvs = map(uv[3],uv[4]) do u, v
            [u,v]
        end

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_initial_guess, trackprop;
            choose_distortions = choose_distortions,
            iterations = 4)

        if abs(distortion[:Y]) > 0.1 + 0.5*abs(camera_initial_guess.xyz[2]) || abs(distortion[:Z]) >= 0.5*abs(camera_initial_guess.xyz[3])
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
    calibrated_camera = VideoCamera(camera_initial_guess, Dict(choose_distortions .=> mean_distortion2))

    return calibrated_camera
end
