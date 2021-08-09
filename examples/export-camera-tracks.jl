using TrainView 

using DataFrames, CSV

# Some track and camera properties
    focal_length = 40e-3
    track_gauge = 1.435

    # horizontal curvature
    β = 0.0

    # vertical curvature
    α = 0.0

    left_track  = [[x, -track_gauge/2.0 + β*x^2, α*x^2] for x = LinRange(4.0,40.0,40)]
    right_track = [[x, track_gauge/2.0 + β*x^2, α*x^2] for x = LinRange(4.0,40.0,40)]

# The reference track image
    cameraposition_reference = [0.0,0.0,2.4];
    camera_reference = VideoCamera(cameraposition_reference;
        focal_length = focal_length
        # , ψθφ = [0.0,-5.0,0.0] .* (pi/180.0)
    )

    left_ref_uvs = camera_image(camera_reference, left_track);
    right_ref_uvs = camera_image(camera_reference, right_track);

# The disturbed track image
    cameraposition = cameraposition_reference + [0.0,-0.06,0.05];
    camera = VideoCamera(cameraposition;
        focal_length = focal_length
        , ψθφ = [1.05,-1.2,0.001] .* (pi/180.0)
    )

    uvs_left = camera_image(camera, left_track);
    uvs_right = camera_image(camera, right_track);

# Save the results
    data_ref = DataFrame(
        left_ref_u = [uv[1] for uv in left_ref_uvs],
        left_ref_v = [uv[2] for uv in left_ref_uvs],
        right_ref_u = [uv[1] for uv in right_ref_uvs],
        right_ref_v = [uv[2] for uv in right_ref_uvs]
    )
    data = DataFrame(
        left_u = [uv[1] for uv in uvs_left],
        left_v = [uv[2] for uv in uvs_left],
        right_u = [uv[1] for uv in uvs_right],
        right_v = [uv[2] for uv in uvs_right]
    )

# CSV.write("reference_image.csv", data_ref)
# CSV.write("disturbed_image.csv", data)

# Plot the results
using Plots

w = camera.opticalproperties.sensor_width;
h = camera.opticalproperties.sensor_height;

plot([-w/2.0,w/2.0,w/2.0,-w/2.0,-w/2.0],[-h/2.0,-h/2.0,h/2.0,h/2.0,-h/2.0], color=:yellow, lab = "")

w = camera_reference.opticalproperties.sensor_width;
h = camera_reference.opticalproperties.sensor_height;

plot!([-w/2.0,w/2.0,w/2.0,-w/2.0,-w/2.0],[-h/2.0,-h/2.0,h/2.0,h/2.0,-h/2.0], color=:red, lab = "")

scatter!([uv[1] for uv in left_ref_uvs],[uv[2] for uv in left_ref_uvs])
scatter!([uv[1] for uv in right_ref_uvs],[uv[2] for uv in right_ref_uvs])
scatter!([uv[1] for uv in left_uvs],[uv[2] for uv in left_uvs])
scatter!([uv[1] for uv in right_uvs],[uv[2] for uv in right_uvs])
