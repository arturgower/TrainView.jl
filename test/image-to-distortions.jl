
@testset "recover camera distortions" begin
    focal_length = 6e-3
    pixelspermeter = 181818.0

    trackprop = TrackProperties(track_gauge = 1.435)

    cameraposition_reference = [0.0,-0.2,-2.4];

    ψθφ_ref = [0.4,-5.0,0.5] .* (pi/180.0);
    camera_reference = VideoCamera(cameraposition_reference;
        focal_length = focal_length,
        pixelspermeter = pixelspermeter,
        ψθφ = ψθφ_ref
    )

    left_track_ref  = [
        [x, -trackprop.track_gauge/2.0, 0.0]
    for x = LinRange(4.0,40.0,40)];

    right_track_ref = [
        [x, trackprop.track_gauge/2.0,0.0]
    for x = LinRange(4.0,40.0,40)];

    left_uvs_ref = camera_image(camera_reference, left_track_ref);
    right_uvs_ref = camera_image(camera_reference, right_track_ref);

    vLs_ref = [uv[2] for uv in left_uvs_ref];
    uLs_ref = [uv[1] for uv in left_uvs_ref];
    vRs_ref = [uv[2] for uv in right_uvs_ref];
    uRs_ref = [uv[1] for uv in right_uvs_ref];

    N = 600;
    dYs = (rand(N) .- 0.5) .* 1e-2;
    dZs = (rand(N) .- 0.5) .* 1e-2;
    dXYZs = [[0,dYs[i],dZs[i]] for i in 1:N];
    XYZ_mean = mean(abs.(d) for d in dXYZs)

    dψθφs = [ [(rand() - 0.5), (rand() - 0.5),0.0] .* (pi/180.0) .* 0.1 for i in 1:N];
    ψθφ_mean = mean(abs.(d) for d in dψθφs)

    # curvatures
    βs = (rand(N) .- 0.5) .* 1e-4 .* 1e-1;
    β_mean = mean(abs.(βs))

    αs = (rand(N) .- 0.5) .* 1e-4.* 1e-1;
    α_mean = mean(abs.(αs))

    δs = [[-dXYZs[i][2:3]; dψθφs[i][1:2]; αs[i]; βs[i]] for i in 1:N];
    δ_mean = [XYZ_mean[2:3]; ψθφ_mean[1:2]; α_mean; β_mean];
    choose_distortions = [:Y,:Z,:ψ,:θ,:α,:β]

    ΔuR = right_track_Δu(camera_reference, trackprop, vRs_ref; choose_distortions = choose_distortions);
    ΔuL = left_track_Δu(camera_reference, trackprop, vLs_ref; choose_distortions = choose_distortions);

    exact_δs = map(1:N) do i

        uLs = uLs_ref + ΔuL * δs[i];
        uRs = uRs_ref + ΔuR * δs[i];

        left_uvs = [ [uLs[j], vLs_ref[j]] for j in eachindex(uLs)];
        right_uvs = [ [uRs[j], vRs_ref[j]] for j in eachindex(uRs)];

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop; choose_distortions = choose_distortions)

        [distortion[s] for s in choose_distortions]
    end;

    error_max = maximum(hcat([abs.(d) for d in δs - exact_δs]...), dims=2)
    error_mean = mean(abs.(d) for d in δs - exact_δs)

    @test maximum(error_max ./ δ_mean) < 1e-11
    @test maximum(error_mean ./ δ_mean) < 1e-12

    # use yaw φ instead of roll ψ
    dψθφs = [ [0.0, (rand() - 0.5),(rand() - 0.5)] .* (pi/180.0) .* 0.1 for i in 1:N];
    ψθφ_mean = mean(abs.(d) for d in dψθφs)

    δs = [[-dXYZs[i][2:3]; dψθφs[i][2:3]; αs[i]; βs[i]] for i in 1:N];
    δ_mean = [XYZ_mean[2:3]; ψθφ_mean[2:3]; α_mean; β_mean];
    choose_distortions = [:Y,:Z,:θ,:φ,:α,:β]

    ΔuR = right_track_Δu(camera_reference, trackprop, vRs_ref; choose_distortions = choose_distortions);
    ΔuL = left_track_Δu(camera_reference, trackprop, vLs_ref; choose_distortions = choose_distortions);

    exact_δs = map(1:N) do i

        uLs = uLs_ref + ΔuL * δs[i];
        uRs = uRs_ref + ΔuR * δs[i];

        left_uvs = [ [uLs[j], vLs_ref[j]] for j in eachindex(uLs)];
        right_uvs = [ [uRs[j], vRs_ref[j]] for j in eachindex(uRs)];

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop; choose_distortions = choose_distortions)

        [distortion[s] for s in choose_distortions]
    end;

    error_max = maximum(hcat([abs.(d) for d in δs - exact_δs]...), dims=2)
    error_mean = mean(abs.(d) for d in δs - exact_δs)

    @test maximum(error_max ./ δ_mean) < 1e-11
    @test maximum(error_mean ./ δ_mean) < 1e-12

    estimate_δs = map(1:N) do i
        left_track  = [
            [x, -trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        right_track = [
            [x, trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        camera = VideoCamera(camera_reference.xyz + dXYZs[i], camera_reference.ψθφ + dψθφs[i], camera_reference.opticalproperties)

        left_uvs = camera_image(camera, left_track);
        right_uvs = camera_image(camera, right_track);

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
            choose_distortions = choose_distortions
            , iterations = 2
        );

        [distortion[s] for s in choose_distortions]
    end;

    error_max = maximum(hcat([abs.(d) for d in δs - estimate_δs]...), dims=2);
    error_mean = mean(abs.(d) for d in δs - estimate_δs);

    # To improve this, I need to add a reference that includes curvature. At the moment, the reference always
    @test maximum(error_max ./ δ_mean) < 0.02
    @test maximum(error_mean ./ δ_mean) < 0.005

    # change angles used
    dψθφs = [ [(rand() - 0.5), (rand() - 0.5),0.0] .* (pi/180.0) .* 0.1 for i in 1:N];
    ψθφ_mean = mean(abs.(d) for d in dψθφs)

    δs = [[-dXYZs[i][2:3]; dψθφs[i][1:2]; αs[i]; βs[i]] for i in 1:N];
    δ_mean = [XYZ_mean[2:3]; ψθφ_mean[1:2]; α_mean; β_mean];
    choose_distortions = [:Y,:Z,:ψ,:θ,:α,:β]

    estimate_δs = map(1:N) do i
        left_track  = [
            [x, -trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        right_track = [
            [x, trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        camera = VideoCamera(camera_reference.xyz + dXYZs[i], camera_reference.ψθφ + dψθφs[i], camera_reference.opticalproperties)

        left_uvs = camera_image(camera, left_track);
        right_uvs = camera_image(camera, right_track);

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
            choose_distortions = choose_distortions
            , iterations = 2
        );

        [distortion[s] for s in choose_distortions]
    end;

    error_max = maximum(hcat([abs.(d) for d in δs - estimate_δs]...), dims=2);
    error_mean = mean(abs.(d) for d in δs - estimate_δs);

    # To improve this, I need to add a reference that includes curvature. At the moment, the reference always
    @test maximum(error_max ./ δ_mean) < 0.025
    @test maximum(error_mean ./ δ_mean) < 0.0055

end

@testset "recover train distortions" begin
    f = 6e-3
    pixelspermeter = 181818.0

    trackprop = TrackProperties(track_gauge = 1.435)

    cameraposition_reference = [0.0,-0.2,-2.4];

    ψθφ_ref = [0.4,-5.0,0.5] .* (pi/180.0);
    camera_reference = VideoCamera(cameraposition_reference;
        sensor_width = 6500,
        sensor_height = 5200,
        focal_length = f,
        pixelspermeter = pixelspermeter,
        ψθφ = ψθφ_ref
    )

    left_track_ref  = [
        [x, -trackprop.track_gauge/2.0, 0.0]
    for x = LinRange(4.0,40.0,40)];

    right_track_ref = [
        [x, trackprop.track_gauge/2.0,0.0]
    for x = LinRange(4.0,40.0,40)];

    left_uvs_ref = camera_image(camera_reference, left_track_ref);
    right_uvs_ref = camera_image(camera_reference, right_track_ref);

    vLs_ref = [uv[2] for uv in left_uvs_ref];
    uLs_ref = [uv[1] for uv in left_uvs_ref];
    vRs_ref = [uv[2] for uv in right_uvs_ref];
    uRs_ref = [uv[1] for uv in right_uvs_ref];

    N = 600;
    dYs = (rand(N) .- 0.5) .* 1e-2;
    dZs = (rand(N) .- 0.5) .* 1e-2;
    dXYZs = [[0,dYs[i],dZs[i]] for i in 1:N];
    XYZ_mean = mean(abs.(d) for d in dXYZs)

    # dψθφs = [ [(rand() - 0.5), (rand() - 0.5),0.0] .* (pi/180.0) .* 0.1 for i in 1:N];
    dψθφs = [ [0.0, (rand() - 0.5), (rand() - 0.5)] .* (pi/180.0) .* 0.1 for i in 1:N];
    ψθφ_mean = mean(abs.(d) for d in dψθφs)

    # curvatures
    βs = (rand(N) .- 0.5) .* 1e-4 .* 1e-1;
    β_mean = mean(abs.(βs))

    αs = (rand(N) .- 0.5) .* 1e-4.* 1e-1;
    α_mean = mean(abs.(αs))

    δs = [[-dXYZs[i][2:3]; dψθφs[i][2:3]; αs[i]; βs[i]] for i in 1:N];
    δ_mean = [XYZ_mean[2:3]; ψθφ_mean[2:3]; α_mean; β_mean];
    choose_distortions = [:Y,:Z,:θT,:φT,:α,:β]

    ΔuR = right_track_Δu(camera_reference, trackprop, vRs_ref; choose_distortions = choose_distortions);
    ΔuL = left_track_Δu(camera_reference, trackprop, vLs_ref; choose_distortions = choose_distortions);

    exact_δs = map(1:N) do i
        uLs = uLs_ref + ΔuL * δs[i];
        uRs = uRs_ref + ΔuR * δs[i];

        left_uvs = [ [uLs[j], vLs_ref[j]] for j in eachindex(uLs)];
        right_uvs = [ [uRs[j], vRs_ref[j]] for j in eachindex(uRs)];

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop; choose_distortions = choose_distortions)

        [distortion[s] for s in choose_distortions]
    end;

    error_max = maximum(hcat([abs.(d) for d in δs - exact_δs]...), dims=2)
    error_mean = mean(abs.(d) for d in δs - exact_δs)

    @test maximum(error_max[[1:3;5:6]] ./ δ_mean[[1:3;5:6]]) < 1e-11
    @test maximum(error_max) < 1e-14

    @test maximum(error_mean[[1:3;5:6]] ./ δ_mean[[1:3;5:6]]) < 1e-12
    @test maximum(error_mean) < 1e-15

    estimate_δs = map(1:N) do i
        left_track  = [
            [x, -trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        right_track = [
            [x, trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        camera = VideoCamera(camera_reference.xyz + dXYZs[i], camera_reference.ψθφ, camera_reference.opticalproperties)

        traincar = TrainCar(dψθφs[i])

        left_uvs = camera_image(camera, left_track, traincar);
        right_uvs = camera_image(camera, right_track, traincar);

        distortion = rail_uvs_to_distortion(left_uvs, right_uvs, camera_reference, trackprop;
            choose_distortions = choose_distortions
            , iterations = 2
        );

        [distortion[s] for s in choose_distortions]
    end;

    error_max = maximum(hcat([abs.(d) for d in δs - estimate_δs]...), dims=2);
    error_mean = mean(abs.(d) for d in δs - estimate_δs);

    # To improve this, I need to add a reference that includes both the traincar position and curvature.

    @test maximum(error_max[[1:3;5:6]] ./ δ_mean[[1:3;5:6]]) < 0.07
    @test maximum(error_max) < 1e-5

    @test maximum(error_mean[[1:3;5:6]] ./ δ_mean[[1:3;5:6]]) < 0.02
    @test maximum(error_mean) < 1e-5

end
