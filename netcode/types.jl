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

struct NetcodeInetAddr
    address::Union{Sockets.InetAddr{Sockets.IPv4}, Sockets.InetAddr{Sockets.IPv6}}
end

struct ClientSlot
    is_used::Bool
    netcode_address::NetcodeInetAddr
end

struct ConnectTokenInfo
    netcode_version_info::Vector{UInt8}
    protocol_id::TYPE_OF_PROTOCOL_ID
    create_timestamp::TYPE_OF_TIMESTAMP
    expire_timestamp::TYPE_OF_TIMESTAMP
    nonce::Vector{UInt8}
    timeout_seconds::TYPE_OF_TIMEOUT_SECONDS
    client_id::TYPE_OF_CLIENT_ID
    netcode_addresses::Vector{NetcodeInetAddr}
    client_to_server_key::Vector{UInt8}
    server_to_client_key::Vector{UInt8}
    user_data::Vector{UInt8}
end

struct PrivateConnectToken
    client_id::TYPE_OF_CLIENT_ID
    timeout_seconds::TYPE_OF_TIMEOUT_SECONDS
    num_server_addresses::TYPE_OF_NUM_SERVER_ADDRESSES
    netcode_addresses::Vector{NetcodeInetAddr}
    client_to_server_key::Vector{UInt8}
    server_to_client_key::Vector{UInt8}
    user_data::Vector{UInt8}
end

struct PrivateConnectTokenAssociatedData
    netcode_version_info::Vector{UInt8}
    protocol_id::TYPE_OF_PROTOCOL_ID
    expire_timestamp::TYPE_OF_TIMESTAMP
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
    netcode_addresses::Vector{NetcodeInetAddr}
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
