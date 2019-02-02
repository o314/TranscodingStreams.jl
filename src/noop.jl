


struct Noop <: Codec end

const NoopStream{S} = TranscodingStream{Noop,S} where S<:IO

NoopStream(stream::IO; kwargs...) = TranscodingStream(Noop(), stream; kwargs...)

function TranscodingStream(codec::Noop, stream::IO;
                           bufsize::Integer=DEFAULT_BUFFER_SIZE,
                           sharedbuf::Bool=(stream isa TranscodingStream))
    checkbufsize(bufsize)
    checksharedbuf(sharedbuf, stream)
    if sharedbuf; buffer = stream.state.buffer1
    else; buffer = Buffer(bufsize)
    end
    TranscodingStream(codec, stream, State(buffer, buffer))
end

"""
    position(stream::NoopStream)

Get the current position of `stream`.

Note that this method may return a wrong position when
- some data have been inserted by `TranscodingStreams.unread`, or
- the position of the wrapped stream has been changed outside of this package.
"""
Base.position(stream::NoopStream) = position(stream.stream) - buffersize(stream.state.buffer1)

Base.seek(stream::NoopStream, pos::Integer) = (seek(stream.stream, pos); initbuffer!(stream.state.buffer1))
Base.seekstart(stream::NoopStream) = (seekstart(stream.stream); initbuffer!(stream.state.buffer1))
Base.seekend(stream::NoopStream) = (seekend(stream.stream); initbuffer!(stream.state.buffer1))

function Base.unsafe_read(stream::NoopStream, output::Ptr{UInt8}, nbytes::UInt)
    changemode!(stream, :read)
    buffer = stream.state.buffer1
    p = output
    p_end = output + nbytes
    while p < p_end && !eof(stream)
        if buffersize(buffer) > 0
            m = min(buffersize(buffer), p_end - p)
            copydata!(p, buffer, m)
        else
            # directly read data from the underlying stream
            m = p_end - p
            Base.unsafe_read(stream.stream, p, m)
        end
        p += m
    end
    if p < p_end && eof(stream); throw(EOFError()) end
end

function Base.unsafe_write(stream::NoopStream, input::Ptr{UInt8}, nbytes::UInt)
    changemode!(stream, :write)
    buffer = stream.state.buffer1
    if marginsize(buffer) ≥ nbytes;     copydata!(buffer, input, nbytes); Int(nbytes)
    else;                               flushbuffer(stream); unsafe_write(stream.stream, input, nbytes)
    end
end

Base.transcode(::Type{Noop}, data::ByteData) = transcode(Noop(), data)
# Copy data because the caller may expect the return object is not the same as from the input.
Base.transcode(::Noop, data::ByteData) = Vector{UInt8}(data)


# Stats
# -----

function stats(s::NoopStream)
    state,mode = s.state, state.mode
    @checkmode (:idle, :read, :write)
    buffer = state.buffer1
    @assert buffer == s.state.buffer2
    if mode == :idle;       consumed = supplied = 0
    elseif mode == :read;   supplied = buffer.total; consumed = supplied-buffersize(buffer)
    elseif mode == :write;  supplied = buffer.total+buffersize(buffer); consumed = buffer.total
    else;                   assert(false)
    end
    return Stats(consumed, supplied, supplied, supplied)
end


# Buffering
# ---------
#
# These methods are overloaded for the `Noop` codec because it has only one
# buffer for efficiency.

function fillbuffer(s::NoopStream)
    changemode!(s, :read)
    buffer = s.state.buffer1
    @assert buffer === s.state.buffer2
    if s.stream isa TranscodingStream && buffer === s.stream.state.buffer1
        # Delegate the operation when buffers are shared.
        return fillbuffer(s.stream)
    end
    nfilled::Int = 0
    while buffersize(buffer) == 0 && !eof(s.stream)
        makemargin!(buffer, 1)
        nfilled += readdata!(s.stream, buffer)
    end
    buffer.total += nfilled
    nfilled
end

function flushbuffer(s::NoopStream, all::Bool=false)
    changemode!(s, :write)
    buffer = s.state.buffer1
    @assert buffer === s.state.buffer2
    nflushed::Int = 0
    if all
        while buffersize(buffer) > 0; nflushed += writedata!(s.stream, buffer) end
    else
        nflushed += writedata!(s.stream, buffer)
        makemargin!(buffer, 0)
    end
    buffer.total += nflushed
    return nflushed
end

flushuntilend(s::NoopStream) = s.state.buffer1.total += writedata!(s.stream, s.state.buffer1)
