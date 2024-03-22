function get_serialized_size(value::Integer)
    if !isbits(value)
        error("Currently only isbits Integer values are supported for serialization")
    else
        return sizeof(value)
    end
end

get_serialized_size(value::Vector{UInt8}) = length(value)

get_serialized_size(value::Union{Sockets.IPv4, Sockets.IPv6}) = get_serialized_size(value.host)

get_serialized_size(value::Union{Sockets.InetAddr{Sockets.IPv4}, Sockets.InetAddr{Sockets.IPv6}}) = get_serialized_size(value.host) + sizeof(value.port)

get_serialized_size(value::NetcodeInetAddr) = SIZE_OF_ADDRESS_TYPE + get_serialized_size(value.address)

get_serialized_size(value::Vector{NetcodeInetAddr}) = sum(get_serialized_size, value)

get_serialized_size_fields(value) = sum(get_serialized_size(getfield(value, i)) for i in 1:fieldcount(typeof(value)))

get_serialized_size(::PrivateConnectToken) = SIZE_OF_ENCRYPTED_PRIVATE_CONNECT_TOKEN_DATA - SIZE_OF_HMAC

get_serialized_size(value::PrivateConnectTokenAssociatedData) = get_serialized_size_fields(value)

get_serialized_size(packet::AbstractPacket) = get_serialized_size_fields(packet)

get_serialized_size(::ConnectTokenPacket) = SIZE_OF_CONNECT_TOKEN_PACKET

function get_serialized_data(value)
    data = zeros(UInt8, get_serialized_size(value))

    io = IOBuffer(data, write = true, maxsize = length(data))

    num_bytes_written = write(io, value)

    @assert num_bytes_written == length(data) "$(num_bytes_written), $(length(data))"

    return data
end

function Base.write(io::IO, netcode_inetaddr::NetcodeInetAddr)
    n = 0

    n += write(io, get_address_type(netcode_inetaddr))
    n += write(io, netcode_inetaddr.address.host.host)
    n += write(io, netcode_inetaddr.address.port)

    return n
end

function Base.write(io::IO, netcode_addresses::Vector{NetcodeInetAddr})
    n = 0

    for netcode_address in netcode_addresses
        n += write(io, netcode_address)
    end

    return n
end

function write_fields(io::IO, value)
    n = 0

    for i in 1:fieldcount(typeof(value))
        n += write(io, getfield(value, i))
    end

    return n
end

function write_fields_and_padding(io::IO, value)
    n = write_fields(io, value)

    serialized_size = get_serialized_size(value)

    padding_size = serialized_size - n

    for i in 1 : padding_size
        n += write(io, UInt8(0))
    end

    return n
end

Base.write(io::IO, private_connect_token::PrivateConnectToken) = write_fields_and_padding(io, private_connect_token)

Base.write(io::IO, private_connect_token_associated_data::PrivateConnectTokenAssociatedData) = write_fields(io, private_connect_token_associated_data)

Base.write(io::IO, packet::AbstractPacket) = write_fields(io, packet)

Base.write(io::IO, packet::ConnectTokenPacket) = write_fields_and_padding(io, packet)
