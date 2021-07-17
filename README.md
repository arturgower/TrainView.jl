# TrainView.jl

To process many frames, each with a large number of points on each track, such as `output_results_centre_line.csv`, go to the terminal and execute
```
> julia camera-distortion.jl data.csv output.csv
```
where `data.csv` is a data file in the same format as `output_results_centre_line.csv`, and `output.csv` is an output file name with the format

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
