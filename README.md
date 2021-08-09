# TrainView.jl

To process many frames, each with a large number of points on each track, such as `data/output_results_centre_line.csv`, go to the terminal, navigate to the same folder as this code, and execute
```
> julia --project track_to_cabin_movement.jl data/output_results_centre_line.csv data/output.csv
```
Or open the julia REPL
```
> julia --project
```
 and then run the code
```julia
julia> include("track_to_cabin_movement.jl")
julia> track_to_cabin_movement("data/output_results_centre_line.csv","data/output.csv")
```
where `output_results_centre_line.csv` is a data file with the track points on images, i.e. see the format of `data/output_results_centre_line.csv`, and `output.csv` is an output file name with the format:

|Y	|Z	|θT |φT |α  |	β  |
|---|---|---|---|---|---|
|-0.0027	|0.035	|-0.0019	|-0.0026	|0.00012	|0.0004|
|-0.0038	|0.011	|-0.0009	|-0.0023	|0.00009	|0.0004|
|-0.00035	|0.0072	|-0.0002	|-0.0016	|0.00005	|0.00005|
| .	| .	| .	| .	| .	|.|
| .	| .	| .	| .	| .	|.|
|0.0088	|-0.0050	|0.0006	|0.0005|	0.0001	| 0.0009|

where each row corresponds to one frame. To explain the columns we first need a coordinate system (X,Y,Z), where X is aligned with the tracks, and pointing forward and Z points towards the ground.

The columns show how much the train car is displaced from being aligned with the tracks. That is, if the values in one row are all zero, then the train is complete aligned with the tracks, and the suspension is in its position of rest. Y and Z are the displacements of the train car in the Y and Z direction, θT and φT are the pitch and yaw of the train car, while α and	β are the vertical and horizontal curvature.

## Execution speed

Julia has a rather large overhead when first initializing. That means the line
```julia
julia> include("track_to_cabin_movement.jl")
julia> @time track_to_cabin_movement("data/output_results_centre_line.csv","data/output.csv")

Data saved as a CSV file in data/output.csv
 29.429744 seconds (107.34 M allocations: 5.266 GiB, 4.69% gc time)
```
but if now run the same function again, without closing julia, then, even if we used different data, the code will run much faster:
```julia
julia> @time track_to_cabin_movement("data/output_results_centre_line.csv","data/output.csv")

Data saved as a CSV file in data/output.csv
  3.366514 seconds (63.07 M allocations: 3.257 GiB, 13.45% gc time)
```
