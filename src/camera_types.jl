struct TrackProperties{T<:AbstractFloat}
    "Width of each rail track"
    track_gauge::T
    "Distance between tracks measured between the inner faces of the rails"
    track_width::T
    "A vector of the orientation, in radians, of the trackbed"
    trackbed_orientation::Vector{T}
    "Width of each sleeper or railroad tie"
    sleeper_width::T
    "Length of each sleeper or railroad tie"
    sleeper_length::T
    "Distance between sleepers or railroad ties"
    sleeper_distance::T
end

function TrackProperties(; track_gauge::T = 1.435, track_width::T = 10e-3, trackbed_orientation::Vector{T} = [0.0], sleeper_width::T = 0.25, sleeper_length::T = 2.6, sleeper_distance::T = 0.70) where T
    return TrackProperties{T}(track_gauge,track_width,trackbed_orientation,sleeper_width,sleeper_length,sleeper_distance)
end

"""
    TracksAhead

Represents everything about the track ahead of the train car. The origin of the coordinate system is on the track ballast and between the two tracks immediately infront of the train car.

The ``(x,y,z)`` of the coordinate system has ``x`` along the rail axis, ``z`` points up towards the sky, and ``y`` then has to point towards the left rail.
"""
struct TracksAhead{T<:AbstractFloat}
    "The positions of the left track when facing forward"
    left_track::Vector{SVector{3,T}}
    "The positions of the right track when facing forward"
    right_track::Vector{SVector{3,T}}
    "the physical properties of the tracks"
    trackproperties::TrackProperties{T}
    function TracksAhead{T}(left_track::Vector{V}, right_track::Vector{V}, trackproperties::TrackProperties{T} = TrackProperties(track_gauge = mean(right_track - left_track)[2])) where {T, V <: AbstractVector{T}}

        if trackproperties.track_gauge < 0
            # throw(DimensionMismatch(""))
            @error "The left_track should be to the left of the right track when ahead of the train. Note the coordinate system used."
        # elseif std(right_track - left_track)[2] > 0.01
        #     @error "The distance between the left_track and right track vary too much."
        else
            new{T}(SVector{3}.(left_track), SVector{3}.(right_track), trackproperties)
        end
    end
end

function TracksAhead(left_track::Vector{V}, right_track::Vector{V}; trackproperties::TrackProperties{T} = TrackProperties(track_gauge = mean(right_track - left_track)[2])) where {T, V <: AbstractVector{T}}

    return TracksAhead{T}(left_track, right_track, trackproperties)

end

"""
    OpticalProperties

Represents everything about the optical properties of the camera.

For the possible fields we have

    - `focal_length`
    - `sensor_width`
    - `sensor_height`
    - `pixelspermeter`
"""
struct OpticalProperties{T<:AbstractFloat}
    "The focal length in meters"
    focal_length::T
    "Sensor width in pixels"
    sensor_width::T
    "Sensor height in pixels"
    sensor_height::T
    "Meters in one pixel length"
    pixelspermeter::T
end

function OpticalProperties(focal_length::T; sensor_width::T = 6500.0, sensor_height::T = 5200.0, pixelspermeter::T = 1 / 5.5e-6) where T
    return OpticalProperties{T}(focal_length,sensor_width,sensor_height,pixelspermeter)
end

"""
    VideoCamera

Represents everything about the camera position and the camera's [`OpticalProperties`](@ref).

For the possible fields we have

    - `xyz` is a vector of the form ``[x,y,z]`` which gives the position of the camera if the track had no defects and the train was still.
    - `ψθφ` is a vector of the form [ψ,θ,φ] where ψ is the roll, θ the pitch, and φ the yaw of the camera.

"""
struct VideoCamera{T<:AbstractFloat}
    xyz::SVector{3,T}
    ψθφ::SVector{3,T}
    opticalproperties::OpticalProperties{T}
end

VideoCamera(xyz::AbstractVector{T}, ψθφ::AbstractVector{T}, opticalproperties::OpticalProperties{T}) where T = VideoCamera{T}(SVector{3,T}(xyz), SVector{3,T}(ψθφ), opticalproperties)

function VideoCamera(cameraposition::AbstractVector{T};
    focalpoint::AbstractVector{T} = [T(30),T(0),T(0)],
    ψθφ::AbstractVector{T} = [T(0); focalθφ(focalpoint,cameraposition)],
    focal_length::T = 6e-3,
    kws...) where T

    return VideoCamera(cameraposition, ψθφ, OpticalProperties(focal_length; kws...))
end

"""
    VideoCamera(camera::VideoCamera{T}, distortion::Dict)

Returns a `VideoCamera` with the same properties as camera, except with the added distortion.
"""
function VideoCamera(camera::VideoCamera{T}, distortion::Dict) where T
    δxyz = [get(distortion, s, zero(T)) for s in [:X,:Y,:Z]]
    δψθφ = [get(distortion, s, zero(T)) for s in [:ψ,:θ,:φ]]

    return VideoCamera(camera.xyz - δxyz, camera.ψθφ + δψθφ, camera.opticalproperties)
end


"""
    focalθφ(focalpoint::Vector, cameraposition::Vector)

Calculate the pitch and yaw of the camera (θ, φ) that would make the focalpoint in 3D be centered in the camera's focus / sensor.
"""
function focalθφ(focalpoint::Vector{T}, cameraposition::Vector{T}) where T
# focalpoint = [xyz[1] + xyz[3]*cot(θ)*cos(φ), xyz[2] + xyz[3]*cot(θ)*sin(φ), 0.0]

    cx, cy, cz = cameraposition

    x = focalpoint[1] - cx
    y = focalpoint[2] - cy

    φ = atan(y,x)
    θ = atan(cz * cos(φ) / x)

    if θ < 0 || abs(φ) > pi
        @warn "unexpected angles θ = $θ or φ = $φ for a camera mounted on a train"
    end

    return [θ, φ]
end

Rψ(ψ::T) where T = SMatrix{3,3}(
    [T(1) T(0)    T(0);
     T(0) cos(ψ)  sin(ψ);
     T(0) -sin(ψ) cos(ψ)]
)

Rθ(θ::T) where T = SMatrix{3,3}(
    [cos(θ) T(0) -sin(θ);
     T(0)   T(1) T(0);
     sin(θ) T(0) cos(θ)]
)

Rφ(φ::T) where T = SMatrix{3,3}(
    [cos(φ)  sin(φ) T(0);
     -sin(φ) cos(φ) T(0);
     T(0)    T(0)   T(1)]
)


"""
    track_image_u(camera::VideoCamera, Y::T, vs::AbstractVector)

returns the us, corresponding to vs, in the camera's image of a track which is aligned with the camera's X axis. This track is assumed to be completely straight, and the camera properties are all known.
"""
function track_image_u(camera::VideoCamera{T}, Y::T, vs::AbstractVector{T}) where T
    Z = - camera.xyz[3]

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    ψ, θ, φ = camera.ψθφ

    a1 = Y * cos(θ) * cos(ψ) - Z * sin(θ) * cos(ψ) * sin(φ) + Z * cos(φ) * sin(ψ)
    a2 = Z * cos(φ) * cos(ψ) + (Z * sin(θ) * sin(φ) - Y * cos(θ)) * sin(ψ)
    a = a1 / a2

    b1 = - f * (Y * sin(θ) + Z * cos(θ) * sin(φ))
    b = b1 / a2

    us = b .+ a .* vs
    return us
end

left_track_image_u(camera::VideoCamera{T}, trackproperties::TrackProperties{T}, vs::AbstractVector{T}) where T = track_image_u(camera, -trackproperties.track_gauge / T(2) - camera.xyz[2], vs)

right_track_image_u(camera::VideoCamera{T}, trackproperties::TrackProperties{T}, vs::AbstractVector{T}) where T = track_image_u(camera, trackproperties.track_gauge / T(2) - camera.xyz[2], vs)

function camera_image(camera::VideoCamera{T}, spatial_points::Vector{V}) where {T, V<:AbstractVector{T}}

    ψ, θ, φ = camera.ψθφ

    R = Rψ(ψ) * Rθ(θ) * Rφ(φ)

    ξηζs = [ R * (xyz - camera.xyz) for xyz in spatial_points]

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    uvs = map(ξηζs) do ξηζ
        scaletopixel = f / ξηζ[1]
        SVector{2}(ξηζ[2:3] .* scaletopixel)
    end

   inside_sensor(uv::SVector{2,T}) = abs(uv[1]) <= camera.opticalproperties.sensor_width / T(2) && abs(uv[2]) <= camera.opticalproperties.sensor_height / T(2)

   return filter(inside_sensor, uvs)

end
