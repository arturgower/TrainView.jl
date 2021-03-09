# function distoration_indices(choose_distortion::Vector{Symbol} = [:Y,:Z,:ψ,:θ,:α,:β])
#     all_distortion_order = [:Y,:Z,:ψ,:θ,:φ,:α,:β]
#     inds = [findfirst(all_distortion_order .== d) for d in choose_distortion]
#     return inds
# end

function camera_distoration(camera_reference::VideoCamera, camera::VideoCamera)

    keys = [:X,:Y,:Z,:ψ,:θ,:φ,:f]
    δ = [- (camera.xyz - camera_reference.xyz);
        camera.ψθφ - camera_reference.ψθφ;
        focal_length(camera) - focal_length(camera_reference)
    ]

    return Dict(keys .=> δ)
end

function rail_uvs_to_distortion(left_track_uvs::AbstractVector{S}, right_track_uvs::AbstractVector{S}, camera_reference::VideoCamera{T}, trackproperties::TrackProperties{T};
        iterations::Int = 1, choose_distortions::Vector{Symbol} = [:Y,:Z,:ψ,:θ,:α,:β]
    ) where {T<:AbstractFloat,S<:AbstractVector{T}}

    uLs = [uv[1] for uv in left_track_uvs];
    vLs = [uv[2] for uv in left_track_uvs];

    uRs = [uv[1] for uv in right_track_uvs];
    vRs = [uv[2] for uv in right_track_uvs];

    camera = camera_reference

    line_distortions = [:Y,:Z,:ψ,:θ,:φ,:f]
    if length(intersect(line_distortions, choose_distortions)) <= 4
        w = zero(T)
    else
        w = eps(T)^T(2/3)
    end

    L = length(choose_distortions)
    δ = zeros(T,L)

    for j = 1:iterations
        ΔuL = left_track_Δu(camera, trackproperties, vLs; choose_distortions = choose_distortions);
        ΔuR = right_track_Δu(camera, trackproperties, vRs;  choose_distortions = choose_distortions);

        M = transpose(ΔuL) * ΔuL + transpose(ΔuR) * ΔuR + w .* I;

        uLs0 = left_track_image_u(camera, trackproperties, vLs);
        uRs0 = right_track_image_u(camera, trackproperties, vRs);
        duLs = uLs0 - uLs;
        duRs = uRs0 - uRs;

        A = - transpose(ΔuL) * duLs - transpose(ΔuR) * duRs;
        δ = inv(M) * A

        camera = VideoCamera(camera, Dict(choose_distortions .=> δ))
    end

    dict = camera_distoration(camera_reference, camera)
    for s in [:α,:β]
        k = findfirst(choose_distortions .== s)
        if !isnothing(k)
            dict[s] = δ[k]
        end
    end

   return dict
end


"""
    Δu(vs::AbstractArray, Y::T, camera::VideoCamera)

Returns an array where Δu[i,j] corresponds to ∂_j u_i, and u_i = u(vs[i]).
"""
function Δu(camera::VideoCamera{T}, Y::T, vs::AbstractArray{T}; choose_distortions::Vector{Symbol} = [:Y,:Z,:ψ,:θ,:α,:β]) where T
    # get the basis functions corresponding to the choose distorations
    fs = [eval(Symbol("v_to_dud",s)) for s in choose_distortions]

    δus = map(fs) do f
        δu = f(camera, Y)
        δu.(vs)
    end

    return hcat(δus...)
end

left_track_Δu(camera::VideoCamera{T}, trackproperties::TrackProperties{T}, vs::AbstractArray{T}; kws...) where T = Δu(camera, - camera.xyz[2] - trackproperties.track_gauge / T(2), vs; kws...)

right_track_Δu(camera::VideoCamera{T}, trackproperties::TrackProperties{T}, vs::AbstractArray{T}; kws...) where T = Δu(camera, - camera.xyz[2] + trackproperties.track_gauge / T(2), vs; kws...)


function v_to_dudf(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    # does not depend on v
    δu(v::T) = (Y*sin(θ) + Z*cos(θ)*sin(φ)) / (Y*cos(θ)*sin(ψ) - Z*(cos(φ)*cos(ψ) + sin(θ)*sin(φ)*sin(ψ)))
    return δu
end

function v_to_dudψ(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    denom = (Z * cos(φ) * cos(ψ) + (-Y * cos(θ) + Z * sin(θ) * sin(φ)) * sin(ψ))^2

    dau = (Z^2 * cos(φ)^2 + (Y * cos(θ) -  Z * sin(θ) * sin(φ))^2) / denom
    dbu = - f * (Y * sin(θ) + Z * cos(θ) * sin(φ)) * (Y * cos(θ) * cos(ψ) - Z * cos(ψ) * sin(θ) * sin(φ) + Z * cos(φ) * sin(ψ)) / denom

    δu(v::T) = dau * v + dbu

    return δu
end

function v_to_dudθ(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter
    denom = (Z * cos(φ) * cos(ψ) + (-Y * cos(θ) + Z * sin(θ) * sin(φ)) * sin(ψ))^2

    dau = - Z * cos(φ) * (Y * sin(θ) + Z * cos(θ) * sin(φ)) / denom
    # dbu = (Z * cos(ψ) * (-2Y * cos(θ) * cos(φ) + Z * sin(θ) * sin(2φ)) + 2 * (Y^2 + Z^2 * sin(φ)^2) * sin(ψ)) / 2

    dbu = Z * cos(φ) * cos(ψ) * (-Y * cos(θ) + Z * sin(θ) * sin(φ)) + (Y^2 + Z^2 * sin(φ)^2) * sin(ψ)
    dbu = f * dbu / denom

    δu(v::T) = dau * v + dbu

    return δu
end

function v_to_dudφ(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter
    denom = (Z * cos(φ) * cos(ψ) + (-Y * cos(θ) + Z * sin(θ) * sin(φ)) * sin(ψ))^2

    dau = Z * (-Z * sin(θ) + Y * cos(θ) * sin(φ)) / denom
    dbu = f * Z * (-cos(ψ) * (Z * cos(θ) + Y * sin(θ) * sin(φ)) + Y * cos(φ) * sin(ψ)) / denom

    δu(v::T) = dau * v + dbu

    return δu
end

function v_to_dudY(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter
    denom = (Z * cos(φ) * cos(ψ) + (-Y * cos(θ) + Z * sin(θ) * sin(φ)) * sin(ψ))^2

    dau = Z * cos(θ) * cos(φ) / denom
    dbu = - f * Z * (cos(φ) * cos(ψ) * sin(θ) + sin(φ) * sin(ψ)) / denom

    δu(v::T) = dau * v + dbu

    return δu
end

function v_to_dudZ(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    denom = (Z * cos(φ) * cos(ψ) + (-Y * cos(θ) + Z * sin(θ) * sin(φ)) * sin(ψ))^2;

    dau = - (Y * cos(θ) * cos(φ)) / denom
    dbu = f * Y * (cos(φ) * cos(ψ) * sin(θ) + sin(φ) * sin(ψ)) / denom

    δu(v::T) = dau * v + dbu

    return δu
end

function v_to_X(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    top = [-f * cos(ψ) * (Z * cos(θ) + Y * sin(θ) * sin(φ)) + f * Y * cos(φ) * sin(ψ),
        -Z * sin(θ) + Y * cos(θ) * sin(φ)]

    bottom = [f * (cos(φ) * cos(ψ) * sin(θ) + sin(φ) * sin(ψ)),
    -cos(θ) * cos(φ)]

    X(v::T) = (top[1] + top[2] * v) / (bottom[1] + bottom[2] * v)

    return X
end

function v_to_dudβ(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    dudY = v_to_dudY(camera, Y; Z = Z)
    X = v_to_X(camera, Y; Z = Z)

    δu(v::T) = dudY(v) * X(v)^2

    return δu
end

function v_to_dudα(camera::VideoCamera{T}, Y::T; Z::T = - camera.xyz[3]) where T
    ψ, θ, φ = camera.ψθφ

    f = camera.opticalproperties.focal_length * camera.opticalproperties.pixelspermeter

    dudZ = v_to_dudZ(camera, Y; Z = Z)
    X = v_to_X(camera, Y;  Z = Z)

    δu(v::T) = dudZ(v) * X(v)^2

    return δu
end
