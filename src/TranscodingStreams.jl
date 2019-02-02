module TranscodingStreams

export
    TranscodingStream,
    Noop,
    NoopStream

const ByteData = Union{Vector{UInt8},Base.CodeUnits{UInt8}}

include("memory_unsafe.jl")
include("buffer.jl")
include("error.jl")
include("codec.jl")
include("state.jl")
include("stream.jl")
include("io_unsafe.jl")
include("noop.jl")
include("transcode.jl")
include("testtools.jl")

end # module
