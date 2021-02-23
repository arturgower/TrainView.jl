include("TrainView.jl")

track_gauge = 1.435

# horizontal curvature
β = 4.5e-4

# vertical curvature
α = -3.2e-4

left_track  = [[x, -track_gauge/2.0 + β*x^2, α*x^2] for x = LinRange(1.0,40.0,40)]
right_track = [[x, track_gauge/2.0 + β*x^2, α*x^2] for x = LinRange(1.0,40.0,40)]

tracks = TracksAhead(left_track,right_track)
spatial_points = [tracks.left_track; tracks.right_track];

# camera = VideoCamera(xyz = [0.0,0.4, 2.4], ψθφ = [0.0,-20.0,10.0] .* (pi/180.0), focal_length = 60e-3)
using Plots; pyplot()

cameraposition = [0.0,0.0,2.4];
camera = VideoCamera(cameraposition;
    focal_length = 40e-3
    # , ψθφ = [0.0,-5.0,0.0] .* (pi/180.0)
)

uvs = camera_image(camera, spatial_points);
us = [uv[1] for uv in uvs];
vs = [uv[2] for uv in uvs];

w = camera.opticalproperties.sensor_width;
h = camera.opticalproperties.sensor_height;

plot([-w/2.0,w/2.0,w/2.0,-w/2.0,-w/2.0],[-h/2.0,-h/2.0,h/2.0,h/2.0,-h/2.0], color=:red, lab = "")
scatter!(us,vs)
