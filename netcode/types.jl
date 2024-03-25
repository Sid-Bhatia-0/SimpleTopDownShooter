import Sockets

struct DebugInfo
    frame_end_time_buffer::Vector{Int}
    frame_time_buffer::Vector{Int}
    update_time_theoretical_buffer::Vector{Int}
    update_time_observed_buffer::Vector{Int}
    sleep_time_theoretical_buffer::Vector{Int}
    sleep_time_observed_buffer::Vector{Int}
end

mutable struct GameState
    reference_time::Int
    frame_number::Int
    target_frame_rate::Int
    target_ns_per_frame::Int
end

struct NetcodeAddress
    address_type::TYPE_OF_ADDRESS_TYPE
    host_ipv4::TYPE_OF_IPV4_HOST
    host_ipv6::TYPE_OF_IPV6_HOST
    port::TYPE_OF_PORT
end

struct ClientSlot
    is_used::Bool
    netcode_address::NetcodeAddress
    client_id::TYPE_OF_CLIENT_ID
end

struct ConnectTokenInfo
    netcode_version_info::Vector{UInt8}
    protocol_id::TYPE_OF_PROTOCOL_ID
    create_timestamp::TYPE_OF_TIMESTAMP
    expire_timestamp::TYPE_OF_TIMESTAMP
    nonce::Vector{UInt8}
    timeout_seconds::TYPE_OF_TIMEOUT_SECONDS
    client_id::TYPE_OF_CLIENT_ID
    netcode_addresses::Vector{NetcodeAddress}
    client_to_server_key::Vector{UInt8}
    server_to_client_key::Vector{UInt8}
    user_data::Vector{UInt8}
end

struct PrivateConnectToken
    client_id::TYPE_OF_CLIENT_ID
    timeout_seconds::TYPE_OF_TIMEOUT_SECONDS
    num_server_addresses::TYPE_OF_NUM_SERVER_ADDRESSES
    netcode_addresses::Vector{NetcodeAddress}
    client_to_server_key::Vector{UInt8}
    server_to_client_key::Vector{UInt8}
    user_data::Vector{UInt8}
end

struct PrivateConnectTokenAssociatedData
    netcode_version_info::Vector{UInt8}
    protocol_id::TYPE_OF_PROTOCOL_ID
    expire_timestamp::TYPE_OF_TIMESTAMP
end

struct ConnectTokenSlot
    last_seen_timestamp::TYPE_OF_TIMESTAMP
    hmac::Vector{UInt8} # TODO(perf): can store hash of hmac instead of hmac
    netcode_address::NetcodeAddress
end

abstract type AbstractPacket end

struct ConnectTokenPacket <: AbstractPacket
    netcode_version_info::Vector{UInt8}
    protocol_id::TYPE_OF_PROTOCOL_ID
    create_timestamp::TYPE_OF_TIMESTAMP
    expire_timestamp::TYPE_OF_TIMESTAMP
    nonce::Vector{UInt8}
    encrypted_private_connect_token_data::Vector{UInt8}
    timeout_seconds::TYPE_OF_TIMEOUT_SECONDS
    num_server_addresses::TYPE_OF_NUM_SERVER_ADDRESSES
    netcode_addresses::Vector{NetcodeAddress}
    client_to_server_key::Vector{UInt8}
    server_to_client_key::Vector{UInt8}
end

struct ConnectionRequestPacket <: AbstractPacket
    packet_type::TYPE_OF_PACKET_TYPE
    netcode_version_info::Vector{UInt8}
    protocol_id::TYPE_OF_PROTOCOL_ID
    expire_timestamp::TYPE_OF_TIMESTAMP
    nonce::Vector{UInt8}
    encrypted_private_connect_token_data::Vector{UInt8}
end

function NetcodeAddress(address::Union{Sockets.InetAddr{Sockets.IPv4}, Sockets.InetAddr{Sockets.IPv6}})
    if address isa Sockets.InetAddr{Sockets.IPv4}
        address_type = ADDRESS_TYPE_IPV4
        host_ipv4 = address.host.host
        host_ipv6 = zero(TYPE_OF_IPV6_HOST)
    else
        address_type = ADDRESS_TYPE_IPV6
        host_ipv4 = zero(TYPE_OF_IPV4_HOST)
        host_ipv6 = address.host.host
    end

    port = address.port

    return NetcodeAddress(address_type, host_ipv4, host_ipv6, port)
end

is_valid(netcode_address::NetcodeAddress) = netcode_address.address_type == ADDRESS_TYPE_IPV4 || netcode_address.address_type == ADDRESS_TYPE_IPV6

function get_inetaddr(netcode_address::NetcodeAddress)
    @assert is_valid(netcode_address)

    if netcode_address.address_type == ADDRESS_TYPE_IPV4
        host = Sockets.IPv4(netcode_address.host_ipv4)
    else
        host = Sockets.IPv6(netcode_address.host_ipv6)
    end

    return Sockets.InetAddr(host, netcode_address.port)
end

function ConnectTokenInfo(client_id)
    create_timestamp = time_ns()
    expire_timestamp = create_timestamp + CONNECT_TOKEN_EXPIRE_SECONDS * 10 ^ 9

    return ConnectTokenInfo(
        NETCODE_VERSION_INFO,
        PROTOCOL_ID,
        create_timestamp,
        expire_timestamp,
        rand(UInt8, SIZE_OF_NONCE),
        TIMEOUT_SECONDS,
        client_id,
        NetcodeAddress.(APP_SERVER_ADDRESSES),
        rand(UInt8, SIZE_OF_KEY),
        rand(UInt8, SIZE_OF_KEY),
        rand(UInt8, SIZE_OF_USER_DATA),
    )
end

function PrivateConnectToken(connect_token_info::ConnectTokenInfo)
    return PrivateConnectToken(
        connect_token_info.client_id,
        connect_token_info.timeout_seconds,
        length(connect_token_info.netcode_addresses),
        connect_token_info.netcode_addresses,
        connect_token_info.client_to_server_key,
        connect_token_info.server_to_client_key,
        connect_token_info.user_data,
    )
end

function PrivateConnectTokenAssociatedData(connect_token_info::ConnectTokenInfo)
    return PrivateConnectTokenAssociatedData(
        connect_token_info.netcode_version_info,
        connect_token_info.protocol_id,
        connect_token_info.expire_timestamp,
    )
end

function PrivateConnectTokenAssociatedData(connection_request_packet::ConnectionRequestPacket)
    return PrivateConnectTokenAssociatedData(
        connection_request_packet.netcode_version_info,
        connection_request_packet.protocol_id,
        connection_request_packet.expire_timestamp,
    )
end

function encrypt(message, associated_data, nonce, key)
    ciphertext = zeros(UInt8, length(message) + SIZE_OF_HMAC)
    ciphertext_length_ref = Ref{UInt}()

    encrypt_status = Sodium.LibSodium.crypto_aead_xchacha20poly1305_ietf_encrypt(ciphertext, ciphertext_length_ref, message, length(message), associated_data, length(associated_data), C_NULL, nonce, key)

    @assert encrypt_status == 0
    @assert ciphertext_length_ref[] == length(ciphertext)

    return ciphertext
end

function try_decrypt(ciphertext, associated_data, nonce, key)
    decrypted = zeros(UInt8, length(ciphertext) - SIZE_OF_HMAC)
    decrypted_length_ref = Ref{UInt}()

    decrypt_status = Sodium.LibSodium.crypto_aead_xchacha20poly1305_ietf_decrypt(decrypted, decrypted_length_ref, C_NULL, ciphertext, length(ciphertext), associated_data, length(associated_data), nonce, key)

    if decrypt_status != 0
        return nothing
    end

    @assert decrypted_length_ref[] == length(decrypted)

    return decrypted
end

function try_decrypt(connection_request_packet::ConnectionRequestPacket, key)
    decrypted = try_decrypt(
        connection_request_packet.encrypted_private_connect_token_data,
        get_serialized_data(PrivateConnectTokenAssociatedData(connection_request_packet)),
        connection_request_packet.nonce,
        key,
    )

    if isnothing(decrypted)
        return nothing
    end

    io = IOBuffer(decrypted)

    private_connect_token = try_read(io, PrivateConnectToken)
    if isnothing(private_connect_token)
        return nothing
    end

    return private_connect_token
end

function ConnectTokenPacket(connect_token_info::ConnectTokenInfo)
    message = get_serialized_data(PrivateConnectToken(connect_token_info))

    associated_data = get_serialized_data(PrivateConnectTokenAssociatedData(connect_token_info))

    encrypted_private_connect_token_data = encrypt(message, associated_data, connect_token_info.nonce, SERVER_SIDE_SHARED_KEY)

    return ConnectTokenPacket(
        connect_token_info.netcode_version_info,
        connect_token_info.protocol_id,
        connect_token_info.create_timestamp,
        connect_token_info.expire_timestamp,
        connect_token_info.nonce,
        encrypted_private_connect_token_data,
        connect_token_info.timeout_seconds,
        length(connect_token_info.netcode_addresses),
        connect_token_info.netcode_addresses,
        connect_token_info.client_to_server_key,
        connect_token_info.server_to_client_key,
    )
end

function ConnectionRequestPacket(connect_token_packet::ConnectTokenPacket)
    return ConnectionRequestPacket(
        PACKET_TYPE_CONNECTION_REQUEST_PACKET,
        connect_token_packet.netcode_version_info,
        connect_token_packet.protocol_id,
        connect_token_packet.expire_timestamp,
        connect_token_packet.nonce,
        connect_token_packet.encrypted_private_connect_token_data,
    )
end
