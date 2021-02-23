
# Some track and camera properties
    focal_length = 40e-3
    # pixelspermeter = 181818.0

    trackprop = TrackProperties(track_gauge = 1.435)

    # horizontal curvature
    β = 4e-6

    # vertical curvature
    α = -3.2e-6

    left_track  = [
        [x, trackprop.track_gauge/2.0 + β*x^2, α*x^2]
    for x = LinRange(4.0,40.0,40)];

    right_track = [
        [x, -trackprop.track_gauge/2.0 + β*x^2, α*x^2]
    for x = LinRange(4.0,40.0,40)];

    cameraposition_reference = [0.0,0.1,2.4];
    ψθφ_ref = [1.0,-5.0,-1.0] .* (pi/180.0);
    camera_reference = VideoCamera(cameraposition_reference;
        ψθφ = ψθφ_ref,
        focal_length = focal_length
        # , pixelspermeter = pixelspermeter
    )

@testset "mapping track to image" begin

    # test two different ways to calculate the us for a straight track
    left_track_ref  = [
        [x, trackprop.track_gauge/2.0, 0.0]
    for x = LinRange(4.0,40.0,40)]

    right_track_ref = [
        [x, -trackprop.track_gauge/2.0, 0.0]
    for x = LinRange(4.0,40.0,40)]

    left_ref_uvs = camera_image(camera_reference, left_track_ref);
    right_ref_uvs = camera_image(camera_reference, right_track_ref);

    uLs_ref = [uv[1] for uv in left_ref_uvs];
    vLs_ref = [uv[2] for uv in left_ref_uvs];
    uRs_ref = [uv[1] for uv in right_ref_uvs];
    vRs_ref = [uv[2] for uv in right_ref_uvs];

    uLs0 = left_track_image_u(camera_reference, trackprop, vLs_ref);
    uRs0 = right_track_image_u(camera_reference, trackprop, vRs_ref);

    @test maximum(abs.(uLs0 - uLs_ref) ./ abs.(uLs_ref)) < 1e-12
    @test maximum(abs.(uRs0 - uRs_ref) ./ abs.(uRs_ref)) < 1e-12

    # Test that linear distortions is the min solution
    left_uvs = camera_image(camera_reference, left_track);
    right_uvs = camera_image(camera_reference, right_track);

    uLs = [uv[1] for uv in left_uvs];
    vLs = [uv[2] for uv in left_uvs];
    uRs = [uv[1] for uv in right_uvs];
    vRs = [uv[2] for uv in right_uvs];

    # use same vs for reference track
    uLs0 = left_track_image_u(camera_reference, trackprop, vLs);
    uRs0 = right_track_image_u(camera_reference, trackprop, vRs);

    duLdβ = v_to_dudβ(camera_reference, trackprop.track_gauge / (2));
    duLdα = v_to_dudα(camera_reference, trackprop.track_gauge / (2));
    duLdβs = duLdβ.(vLs);
    duLdαs = duLdα.(vLs);

    duRdβ = v_to_dudβ(camera_reference, -trackprop.track_gauge / (2));
    duRdα = v_to_dudα(camera_reference, -trackprop.track_gauge / (2));
    duRdβs = duRdβ.(vRs);
    duRdαs = duRdα.(vRs);

    # The local minimum choice for β and α should be the values used for the ref track.
    βs = LinRange(0, β, 20);
    αs = LinRange(0, α, 20);

    uLs_arr = [duLdβs .* β + duLdαs .* α + uLs0 for β in βs];
    uRs_arr = [duRdβs .* β + duRdαs .* α + uRs0 for α in αs];

    m, i = findmin([norm(us - uLs) for us in uLs_arr])
    @test m / norm(uLs) < 1e-3
    @test norm(βs[i] - β) / β < 1e-5

    m, i = findmin([norm(us - uRs) for us in uRs_arr])
    @test m / norm(uRs) < 1e-3
    @test norm(αs[i] - α) / α < 1e-5
end


@testset "camera distortions" begin

    N = 1000;
    dYs = (rand(N) .- 0.5) .* 0.1;
    dZs = (rand(N) .- 0.5) .* 0.1;
    dXYZs = [[0,dYs[i],dZs[i]] for i in 1:N];
    dψθφs = [[(rand() - 0.5), (rand() - 0.5), 0.0] .* (0.5 * pi/180.0) for i in 1:N];

    # curvatures
    βs = (rand(N) .- 0.5) .* 1e-5;
    αs = (rand(N) .- 0.5) .* 1e-5;

    δs = [ [-dXYZs[i][2:3]; dψθφs[i][1:2]; αs[i]; βs[i]] for i in 1:N];

    choose_distortions = [:Y,:Z,:ψ,:θ,:α,:β]

    data = map(1:N) do i

        left_track  = [
            [x, trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        right_track = [
            [x, -trackprop.track_gauge/2.0 + βs[i] * x^2, αs[i] *x^2]
        for x = LinRange(4.0,40.0,40)];

        camera = VideoCamera(cameraposition_reference + dXYZs[i];
            focal_length = focal_length
            , ψθφ = ψθφ_ref + dψθφs[i]
        );

        left_uvs = camera_image(camera, left_track);
        right_uvs = camera_image(camera, right_track);

        vLs = [uv[2] for uv in left_uvs];
        uLs = [uv[1] for uv in left_uvs];
        vRs = [uv[2] for uv in right_uvs];
        uRs = [uv[1] for uv in right_uvs];

        uLs_ref = left_track_image_u(camera_reference, trackprop, vLs);
        uRs_ref = right_track_image_u(camera_reference, trackprop, vRs);

        ΔuL = left_track_Δu(camera_reference, trackprop, vLs; choose_distortions=choose_distortions)
        ΔuR = right_track_Δu(camera_reference, trackprop, vRs; choose_distortions=choose_distortions)

        nL = maximum(abs.(uLs - (uLs_ref + ΔuL * δs[i]))) / mean(abs.(uLs))
        sL = sum(uLs - (uLs_ref + ΔuL * δs[i])) / sum(abs.(uLs))

        nR = maximum(abs.(uRs - (uRs_ref + ΔuR * δs[i]))) / mean(abs.(uRs))
        sR = sum(uRs - (uRs_ref + ΔuR * δs[i])) / sum(abs.(uRs))
        [nL,nR,sL,sR]
    end;

    nLs = [d[1] for d in data];
    nRs = [d[2] for d in data];
    sLs = [d[3] for d in data];
    sRs = [d[4] for d in data];

    @test maximum(nLs) < 0.02
    @test mean(nLs) < 0.002
    @test abs(mean(sLs)) < 0.001

    @test maximum(nRs) < 0.02
    @test mean(nRs) < 0.005
    @test abs(mean(sRs)) < 0.001

    # plot(uLs,vLs)
    # scatter!(uLs_ref,vLs)
    # plot!(uLs_ref + ΔuL * δ,vLs,linestyle = :dash, linewidth = 2)
    # #
    # plot(uRs,vRs)
    # scatter!(uRs_ref,vRs)
    # plot!(uRs_ref + ΔuR * δ,vRs,linestyle = :dash, linewidth = 2)

end
