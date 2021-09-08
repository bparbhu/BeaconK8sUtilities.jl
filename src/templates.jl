# https://github.com/invenia/PkgTemplates.jl/blob/4302ecb0a8f3304ca519796bae70c196794692c9/src/plugin.jl#L306-L316
"""
    gen_file(file, text::AbstractString)

Create a new file containing some given text.
Trailing whitespace is removed, and the file will end with a newline.
"""
function gen_file(file, text::AbstractString)
    mkpath(dirname(file))
    text = strip(join(map(rstrip, split(text, "\n")), "\n")) * "\n"
    return write(file, text)
end

"""
    setup_tensorboard(destination::AbstractString; app::AbstractString,
                      logdir::AbstractString,
                      ecr::AbstractString = default_ecr(),
                      service_account::AbstractString = default_service_account(),
                      namespace::AbstractString = get_current_namespace(),
                      local_port::Int=6006, overwrite=false)

Sets up a tensorboard launch scripts in destination directory `destination`, which
does not have to exist ahead of time.

* `app`: name of project/application/model that you are using tensorboard with
  (used for labelling the pods and keeping track of which is which)
* `logdir`: log directory that tensorboard should be pointing at. May be an `s3` URI
* `ecr`: name of the ECR repo to use to push docker images to. Can set this as a default
  with [`default_ecr`](@ref).
* `service_account`: name of the Kubernetes service account. Can set this as a default
  with [`default_service_account`](@ref).
* `namespace`: name of the Kubernetes namespace to use. Defaults to the current active
  one introspected by [`get_current_namespace`](@ref).
* `local_port`: local port to use when port forwarding.
* `overwrite`: whether or not to overwrite existing configuration scripts.

"""
function setup_tensorboard(destination::AbstractString; app::AbstractString,
                           logdir::AbstractString, ecr::AbstractString=default_ecr(),
                           service_account::AbstractString=default_service_account(),
                           namespace::AbstractString=get_current_namespace(),
                           local_port::Int=6006, overwrite=false)
    isfile(destination) && throw(ArgumentError("""
            Destination $destination exists and is a file.
            Must be a directory (or nonexistent in which case a directory will be created).
        """))

    variables = Dict("app" => app, "logdir" => logdir, "ecr" => ecr,
                     "service_account" => service_account, "local_port" => local_port,
                     "namespace" => namespace)

    template_dir = joinpath(TEMPLATES, "tensorboard")

    for name in readdir(template_dir)
        text = render(read(joinpath(template_dir, name), String), variables)
        path = joinpath(destination, name)
        if !overwrite && isfile(path)
            error("$path already exists; set `overwrite=true` to overwrite existing files.")
        end
        @info("Writing $(path)")
        gen_file(path, text)
    end

    @info tensorboard_instructions()

    return nothing
end

function tensorboard_instructions()
    return """
After calling `setup_tensorboard(destination; kwargs...)` to setup the configuration scripts in a destination directory:

1. Run `chmod +x destination/tensorboard.sh` to make the script executable.
2. Make sure to add `K8sUtilities` to your global Julia environment so that it can be used from the `tensorboard.sh` script.

Then running `destination/tensorboard.sh` in a shell should launch a tensorboard pod,
or give you the option to connect to an existing one.

Note: You can edit these files freely; running `setup_tensorboard` with `overwrite=true` will replace them with the latest defaults.
"""
end