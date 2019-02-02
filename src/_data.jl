


#-------------------------------------------------------------------------------
# STATE

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


#-------------------------------------------------------------------------------
# ERROR

"""
Container of transcoding error.
An object of this type is used to notify the caller of an exception that
happened inside a transcoding method.  The `error` field is undefined at first
but will be filled when data processing failed. The error should be set by
calling the `setindex!` method (e.g. `error[] = ErrorException("error!")`).
"""
mutable struct Error
    error::Exception
    Error() = new()
end

# Test if an exception is set.
haserror(error::Error) = isdefined(error, :error)
Base.setindex!(error::Error, ex::Exception) = ((@assert !haserror(error) "an error is already set"); error.error = ex; error)
Base.getindex(error::Error) = (@assert haserror(error) "no error is set"); error.error

