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

get_serialized_size(value::NetcodeAddress) = SIZE_OF_ADDRESS_TYPE + get_serialized_size(value.address)

get_serialized_size(value::Vector{NetcodeAddress}) = sum(get_serialized_size, value)

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

function Base.write(io::IO, netcode_inetaddr::NetcodeAddress)
    n = 0

    n += write(io, get_address_type(netcode_inetaddr))
    n += write(io, netcode_inetaddr.address.host.host)
    n += write(io, netcode_inetaddr.address.port)

    return n
end

function Base.write(io::IO, netcode_addresses::Vector{NetcodeAddress})
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

function try_read(io::IO, ::Type{NetcodeAddress})
    address_type = read(io, TYPE_OF_ADDRESS_TYPE)

    if address_type == ADDRESS_TYPE_IPV4
        host = Sockets.IPv4(read(io, TYPE_OF_IPV4_HOST))
        port = read(io, TYPE_OF_IPV4_PORT)
    elseif address_type == ADDRESS_TYPE_IPV6
        host = Sockets.IPv6(read(io, TYPE_OF_IPV6_HOST))
        port = read(io, TYPE_OF_IPV6_PORT)
    else
        return nothing
    end

    return NetcodeAddress(Sockets.InetAddr(host, port))
end

function try_read(data::Vector{UInt8}, ::Type{ConnectTokenPacket})
    if length(data) != SIZE_OF_CONNECT_TOKEN_PACKET
        return nothing
    end

    io = IOBuffer(data)

    netcode_version_info = read(io, SIZE_OF_NETCODE_VERSION_INFO)
    if netcode_version_info != NETCODE_VERSION_INFO
        return nothing
    end

    protocol_id = read(io, TYPE_OF_PROTOCOL_ID)
    if protocol_id != PROTOCOL_ID
        return nothing
    end

    create_timestamp = read(io, TYPE_OF_TIMESTAMP)
    expire_timestamp = read(io, TYPE_OF_TIMESTAMP)
    if expire_timestamp < create_timestamp
        return nothing
    end

    nonce = read(io, SIZE_OF_NONCE)

    encrypted_private_connect_token_data = read(io, SIZE_OF_ENCRYPTED_PRIVATE_CONNECT_TOKEN_DATA)

    timeout_seconds = read(io, TYPE_OF_TIMEOUT_SECONDS)

    num_server_addresses = read(io, TYPE_OF_NUM_SERVER_ADDRESSES)
    if !(1 <= num_server_addresses <= MAX_NUM_SERVER_ADDRESSES)
        return nothing
    end

    netcode_addresses = NetcodeAddress[]

    for i in 1:num_server_addresses
        netcode_address = try_read(io, NetcodeAddress)
        if !isnothing(netcode_address)
            push!(netcode_addresses, netcode_address)
        else
            return nothing
        end
    end

    client_to_server_key = read(io, SIZE_OF_KEY)

    server_to_client_key = read(io, SIZE_OF_KEY)

    while !eof(io)
        x = read(io, UInt8)
        if x != 0
            return nothing
        end
    end

    connect_token_packet = ConnectTokenPacket(
        netcode_version_info,
        protocol_id,
        create_timestamp,
        expire_timestamp,
        nonce,
        encrypted_private_connect_token_data,
        timeout_seconds,
        num_server_addresses,
        netcode_addresses,
        client_to_server_key,
        server_to_client_key,
    )

    return connect_token_packet
end

function try_read(data::Vector{UInt8}, ::Type{ConnectionRequestPacket})
    if length(data) != SIZE_OF_CONNECTION_REQUEST_PACKET
        return nothing
    end

    io = IOBuffer(data)

    packet_type = read(io, TYPE_OF_PACKET_TYPE)
    if packet_type != PACKET_TYPE_CONNECTION_REQUEST_PACKET
        return nothing
    end

    netcode_version_info = read(io, SIZE_OF_NETCODE_VERSION_INFO)
    if netcode_version_info != NETCODE_VERSION_INFO
        return nothing
    end

    protocol_id = read(io, TYPE_OF_PROTOCOL_ID)
    if protocol_id != PROTOCOL_ID
        return nothing
    end

    expire_timestamp = read(io, TYPE_OF_TIMESTAMP)
    if expire_timestamp <= time_ns()
        return nothing
    end

    nonce = read(io, SIZE_OF_NONCE)

    encrypted_private_connect_token_data = read(io, SIZE_OF_ENCRYPTED_PRIVATE_CONNECT_TOKEN_DATA)

    connection_request_packet = ConnectionRequestPacket(
        packet_type,
        netcode_version_info,
        protocol_id,
        expire_timestamp,
        nonce,
        encrypted_private_connect_token_data,
    )

    return connection_request_packet
end
