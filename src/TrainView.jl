module TrainView

export TracksAhead,TrackProperties, OpticalProperties, TrainCar
export VideoCamera, focal_length, focalθφ, track_image_u, camera_image, left_track_image_u, right_track_image_u
export camera_distoration, rail_uvs_to_distortion, Δu, left_track_Δu, right_track_Δu

# methods that project small changes in track curvature to image of track
export v_to_dudβ, v_to_dudα

import StaticArrays: SVector, SMatrix

using LinearAlgebra
using Statistics
using RecipesBase

include("camera_types.jl")
include("camera_distortion.jl")
include("../plot/tracksahead.jl")


end
