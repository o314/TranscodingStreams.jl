# Transcoding State
# =================

# See docs/src/devnotes.md.
"""
A mutable state type of transcoding streams.

See Developer's notes for details.
"""
mutable struct State
    mode::Symbol        # current stream mode; in {:idle, :read, :write, :stop, :close, :panic}
    code::Symbol        # return code of the last method call; in {:ok, :end, :error} 
    stop_on_end::Bool   # flag to go :stop on :end
    error::Error        # exception thrown while data processing
    buffer1::Buffer     # data buffers
    buffer2::Buffer     # "

    State(buffer1::Buffer, buffer2::Buffer) = new(:idle, :ok, false, Error(), buffer1, buffer2)
end

State(size::Integer) = State(Buffer(size), Buffer(size))
