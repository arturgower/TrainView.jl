function load_uv_data(input_uv_file::String;
        sensor_width::Int = 960, sensor_height::Int = 540,
    )

    !isfile(input_uv_file) && @error "there is no file: $input_uv_file"

    println("Loading data file from:", input_uv_file)
    println("I hope it's in the right format!")

    lines = open(input_uv_file) do f
        [l for l in eachline(f)]
    end;

    header = lines[1];
    lines = lines[2:end];
    frames = Array{Float64}(undef, length(lines))

    uv_data = map(eachindex(lines)) do i
        l = lines[i]
        spl = split(l,',')
        frames[i] = parse(Float64,spl[1])

        # the end of the file might have a space or nothing. Just in case other non-numeric entries appear we use the below
        i1 = findfirst(
            s -> !isnothing(tryparse(Float64,s)),
        reverse(spl))

        data = parse.(Float64,spl[2:end - (i1 - 1)])

        # the number of data points for the left rail
        Llen = Int(data[1])

        # the number of data points for the right rail
        Rlen = Int(data[2])

        us = data[3:2:end] .- (sensor_width / 2.0);
        vs = data[4:2:end] .- (sensor_height / 2.0);

        Lu = us[1:Llen];
        Lv = vs[1:Llen];

        Ru = us[Llen+1:Rlen+Llen];
        Rv = vs[Llen+1:Rlen+Llen];

        return [Lu,Lv,Ru,Rv]
    end;

    return frames, uv_data
end
