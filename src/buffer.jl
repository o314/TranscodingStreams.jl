# Buffer
# ======

# Data Layout
# -----------
#
# Buffered data are stored in `data` and three position fields are used to keep
# track of marked data, buffered data and margin.
#
#             marked      buffer      margin
#          |<-------->||<-------->||<-------->|
#     |....xxxxxxxxxxxxXXXXXXXXXXXX...........|
#     ^    ^           ^           ^          ^
#     1    markpos     bufferpos   marginpos  lastindex(data)
#
# `markpos` is positive iff there are marked data; otherwise it is set to zero.
# `markpos` ≤ `bufferpos` ≤ `marginpos` must hold whenever possible.

mutable struct Buffer
    # data and positions (see above)
    data::Vector{UInt8}
    markpos::Int
    bufferpos::Int
    marginpos::Int

    # the number of total bytes passed through this buffer
    total::Int64

    Buffer(size::Integer) = new(Vector{UInt8}(undef, size), 0, 1, 1, 0)
    Buffer(data::Vector{UInt8}) = new(data, 0, 1, length(data)+1, 0)
end

Buffer(data::Base.CodeUnits{UInt8}) = Buffer(Vector{UInt8}(data))
Base.length(buf::Buffer) = length(buf.data)
bufferptr(buf::Buffer) = pointer(buf.data, buf.bufferpos)
buffersize(buf::Buffer) = buf.marginpos - buf.bufferpos
buffermem(buf::Buffer) = Memory(bufferptr(buf), buffersize(buf))
marginptr(buf::Buffer) = pointer(buf.data, buf.marginpos)
marginsize(buf::Buffer) = lastindex(buf.data) - buf.marginpos + 1
marginmem(buf::Buffer) = Memory(marginptr(buf), marginsize(buf))
ismarked(buf::Buffer) = buf.markpos != 0
mark!(buf::Buffer) = buf.markpos = buf.bufferpos
unmark!(buf::Buffer) = if buf.markpos==0; false else; buf.markpos=0; true end

function reset!(buf::Buffer)
    @assert buf.markpos > 0
    buf.bufferpos = buf.markpos
    buf.markpos = 0
    return buf.bufferpos
end

consumed!(buf::Buffer, n::Integer) = (buf.bufferpos += n; buf) # Notify that `n` bytes are consumed from `buf`.
supplied!(buf::Buffer, n::Integer) = (buf.marginpos += n; buf) # Notify that `n` bytes are supplied to `buf`.
consumed2!(buf::Buffer, n::Integer) = (buf.bufferpos += n; buf.total += n; buf)
supplied2!(buf::Buffer, n::Integer) = (buf.marginpos += n; buf.total += n; buf)
initbuffer!(buf::Buffer) = (buf.markpos = 0; buf.bufferpos = buf.marginpos = 1; buf.total = 0; buf) # Discard buffered data and initialize positions.
emptybuffer!(buf::Buffer) = (buf.marginpos = buf.bufferpos; buf) # Remove all buffered data.

# Make margin with ≥`minsize` and return the size of it.
function makemargin!(buf::Buffer, minsize::Integer)
    @assert minsize ≥ 0
    if buffersize(buf) == 0 && buf.markpos == 0
        buf.bufferpos = buf.marginpos = 1
    end
    if marginsize(buf) < minsize
        # shift data to left
        if buf.markpos == 0
            datapos = buf.bufferpos
            datasize = buffersize(buf)
        else
            datapos = buf.markpos
            datasize = buf.marginpos - buf.markpos
        end
        copyto!(buf.data, 1, buf.data, datapos, datasize)
        shift = datapos - 1
        if buf.markpos > 0
            buf.markpos -= shift
        end
        buf.bufferpos -= shift
        buf.marginpos -= shift
    end
    if marginsize(buf) < minsize
        # expand data buffer
        resize!(buf.data, buf.marginpos + minsize - 1)
    end
    @assert marginsize(buf) ≥ minsize
    return marginsize(buf)
end

readbyte!(buf::Buffer) = (b = buf.data[buf.bufferpos]; consumed!(buf, 1); b) # Read a byte.
writebyte!(buf::Buffer, b::UInt8) = (buf.data[buf.marginpos] = b; supplied!(buf, 1); 1) # Write a byte.
skipbuffer!(buf::Buffer, n::Integer) = ((@assert n ≤ buffersize(buf)); consumed!(buf, n); buf) # Skip `n` bytes in the buffer.


# Take the ownership of the marked data.
function takemarked!(buf::Buffer)
    @assert buf.markpos > 0
    sz = buf.marginpos - buf.markpos
    copyto!(buf.data, 1, buf.data, buf.markpos, sz)
    initbuffer!(buf)
    return resize!(buf.data, sz)
end

# Copy data from `data` to `buf`.
function copydata!(buf::Buffer, data::Ptr{UInt8}, nbytes::Integer)
    makemargin!(buf, nbytes)
    unsafe_copyto!(marginptr(buf), data, nbytes)
    supplied!(buf, nbytes)
    return buf
end

# Copy data from `buf` to `data`.
function copydata!(data::Ptr{UInt8}, buf::Buffer, nbytes::Integer)
    # NOTE: It's caller's responsibility to ensure that the buffer has at least
    # nbytes.
    @assert buffersize(buf) ≥ nbytes
    unsafe_copyto!(data, bufferptr(buf), nbytes)
    consumed!(buf, nbytes)
    return data
end

# Insert data to the current buffer.
function insertdata!(buf::Buffer, data::Ptr{UInt8}, nbytes::Integer)
    makemargin!(buf, nbytes)
    copyto!(buf.data, buf.bufferpos + nbytes, buf.data, buf.bufferpos, buffersize(buf))
    unsafe_copyto!(bufferptr(buf), data, nbytes)
    supplied!(buf, nbytes)
    return buf
end

# Find the first occurrence of a specific byte.
function findbyte(buf::Buffer, byte::UInt8)
    p = ccall(
        :memchr,
        Ptr{UInt8},
        (Ptr{UInt8}, Cint, Csize_t),
        pointer(buf.data, buf.bufferpos), byte, buffersize(buf))
    if p == C_NULL
        return marginptr(buf)
    else
        return p
    end
end
