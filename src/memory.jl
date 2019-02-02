"""
A contiguous memory.

This type works like a `Vector` method.
"""
struct Memory
    ptr::Ptr{UInt8}
    size::UInt
end

Memory(data::ByteData) = Memory(pointer(data), sizeof(data))
Base.length(mem::Memory) = mem.size
Base.lastindex(mem::Memory) = Int(mem.size)
Base.checkbounds(mem::Memory, i::Integer) = (1 ≤ i ≤ lastindex(mem)) || throw(BoundsError(mem, i))
Base.getindex(mem::Memory, i::Integer) = (@boundscheck checkbounds(mem, i); unsafe_load(mem.ptr, i))
Base.setindex!(mem::Memory, val::UInt8, i::Integer) = (@boundscheck checkbounds(mem, i); unsafe_store!(mem.ptr, val, i))
