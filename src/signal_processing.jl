moving_average(vs,n) = [mean(vs[i:(i+n-1)]) for i in 1:(length(vs)-(n-1))]

function rolling_average(df::DataFrame, n::Int = 60; kws... )

    propnames = propertynames(df)

    data = [
        rolling_average(df[!,j],n; fits = df[!,:fit], kws...)
    for j in eachindex(propnames)]

    # dfm1 = DataFrame(hcat(frames1_avg,t1_avg,y1_avg,z1_avg,θT1_avg,α1_avg,β1_avg),[:frame,:time,:Y,:Z,:θT,:α,:β])
    return DataFrame(propnames .=> data)
end


function rolling_average(vs::AbstractVector, n::Int = Int(round(length(vs)/200)) + 1;
        fits = zeros(length(vs)), σ_ratio = 1.0
    )
    [
    mean(
        begin
            vpart = vs[i:(i+n-1)]
            inds = findall(fits[i:(i+n-1)] .< 0.5)
            if isempty(inds) @error "too many points that do not fit the calibration" end
            vpart = vpart[inds]

            vmean = mean(vpart);
            vstd = std(vpart);
            bits = abs.(vpart .- vmean) .< σ_ratio * vstd;
            vpart[bits]
            # vsort = sort(vpart, by = v -> abs(v - vmean));
            # vsort[1:Int(round(n/2))]
        end
    )
    for i in 1:(length(vs)-(n-1))]
end
