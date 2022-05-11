function load_uv_data(input_uv_file::String;
        max_v::Int = 720, max_u::Int = 1280
    )

    !isfile(input_uv_file) && @error "there is no file: $input_uv_file"

    println("Loading data file from:", input_uv_file)
    println("I hope it's in the right format!")

    lines = open(input_uv_file) do f
        [l for l in eachline(f)]
    end;

    header = lines[1];
    lines = lines[2:end];

    uv_data = map(lines) do l
        data = parse.(Int,split(l,',')[2:end-1])

        Llen = data[1]
        Rlen = data[2]

        us = data[3:2:end] .- (max_u / 2.0);
        vs = data[4:2:end] .- (max_v / 2.0);

        Lu = us[1:Llen];
        Lv = vs[1:Llen];

        Ru = us[Llen+1:Rlen+Llen];
        Rv = vs[Llen+1:Rlen+Llen];

        return [Lu,Lv,Ru,Rv]
    end;

    return uv_data
end
