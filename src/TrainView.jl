module TrainView

# The most important types
export TracksAhead,TrackProperties, OpticalProperties, TrainCar, VideoCamera

# Functions used to generate images from a camera
export focal_length, focalθφ, track_image_u, camera_image, left_track_image_u, right_track_image_u

# Functions used figure out how the camera has moved relative to some reference
export camera_calibration, camera_distoration, rail_uvs_to_distortion, Δu, left_track_Δu, right_track_Δu

# methods that project small changes in track curvature to image of track
export v_to_dudβ, v_to_dudα

# Useful support functions 
export load_uv_data

import StaticArrays: SVector, SMatrix

using LinearAlgebra
using Statistics
using RecipesBase

include("camera_types.jl")
include("utils.jl")
include("camera_distortion.jl")
include("camera_calibration.jl")
include("../plot/tracksahead.jl")


end
