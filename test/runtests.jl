using Test, TrainView
using LinearAlgebra, Statistics

include("track-to-image.jl")
include("image-to-distortions.jl")

# process some data
include("../track_to_cabin_movement.jl")
track_to_cabin_movement("../data/output_results_centre_line.csv","../data/output.csv")
