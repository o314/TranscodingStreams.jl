# Codec Interfaces
# ================

"""
### TRANSCODING PROTOCOL (HAPPY PATH)


| NAME              | QTY   | DESC                                              | RETURN                                | HAS DEFAULT?  |
+-------------------+-------+---------------------------------------------------+---------------------------------------+---------------+
| `minoutsize`      | 0:1   |                                                   | minimum output size of `process`      | x             |
| `expectedsize`    | 0:1   |                                                   | expected size of transcoded data      | x             |
| `initialize`      | 0:1   | initialize the codec. called once and only once   |                                       | x             |
| `startproc`       | 0:1   | start processing with the codec                   |                                       | x             |
| `process`         | 1:1   | process data with the codec. called repeatedly    | `(read_size, written_size, :ok)`      | -             |
|                   |       |                                                   | `:end`                                |               |
| `finalize`        | 0:1   | finalize the codec. called once and only once     |                                       | x             |


### ENUMS

MODE
- :idle
- :read
- :write
- :stop
- :close
- :panic

CODE
- :ok
- :end
- :error


### ERROR MGT

todo

"""

abstract type Codec end


expectedsize(codec::Codec, input::Memory)::Int = input.size
minoutsize(codec::Codec, input::Memory)::Int = max(1, div(input.size, 4))
initialize(codec::Codec) = nothing
finalize(codec::Codec)::Nothing = nothing
startproc(codec::Codec, mode::Symbol, error::Error)::Symbol = :ok
process(codec::Codec, input::Memory, output::Memory, error::Error)::Tuple{Int,Int,Symbol} =
    throw(MethodError(process, (codec, input, output, error)))
