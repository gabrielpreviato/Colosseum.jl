using Sockets
using Serialization
using MsgPack

using Colosseum

RESPONSE = 0x01

struct VehicleClient
    client::TCPSocket
end

function VehicleClient(ip::String="127.0.0.1", port::Int=41451)
    client = connect(ip, port)

    VehicleClient(client)
end

function call(c::VehicleClient, method::String, args...; idx::UInt8=0x00)
    bytes = pack(c.client, [0x00, idx, method, [args...]])
    msg = unpack(c.client)

    if msg[1] != RESPONSE
        throw("call to method $method didn't return a RESPONSE")
    elseif msg[2] != idx
        throw("call to method $method returned IDX $(msg[2]), but call was made with IDX $idx")
    elseif msg[3] !== nothing
        throw(msg[3])
    end

    println(msg[1:3])

    return msg[4]
end

#----------------------------------- Common vehicle APIs ---------------------------------------------

function reset(c::VehicleClient)
    """
    Reset the vehicle to its original starting state

    Note that you must call `enableApiControl` and `armDisarm` again after the call to reset
    """
    call(c, "reset")
end

function ping(c::VehicleClient)
    """
    If connection is established then this call will return true otherwise it will be blocked until timeout

    Returns:
        bool:
    """
    call(c, "ping")
end

function getClientVersion(c::VehicleClient)
        return 1 # sync with C++ client
end

function getServerVersion(c::VehicleClient)
    return call(c, "getServerVersion")
end

function getMinRequiredServerVersion(c::VehicleClient)
    return 1 # sync with C++ client
end

function getMinRequiredClientVersion(c::VehicleClient)
    """
    Enables or disables API control for vehicle corresponding to vehicle_name

    Args:
        is_enabled (bool): True to enable, False to disable API control
        vehicle_name (str, optional): Name of the vehicle to send this command to
        """
    return call(c, "getMinRequiredClientVersion")
end

# Basic flight control
function enableApiControl(c::VehicleClient, is_enabled::Bool, vehicle_name::String="")
    call(c, "enableApiControl", is_enabled, vehicle_name)
end

function isApiControlEnabled(c::VehicleClient, vehicle_name::String="")
    """
    Returns true if API control is established.

    If false (which is default) then API calls would be ignored. After a successful call to `enableApiControl`, `isApiControlEnabled` should return true.

    Args:
        vehicle_name (str, optional): Name of the vehicle

    Returns:
        bool: If API control is enabled
    """
    call(c, "isApiControlEnabled", vehicle_name)
end

function armDisarm(c::VehicleClient, arm::Bool, vehicle_name::String="")
    """
    Arms or disarms vehicle

    Args:
        arm (bool): True to arm, False to disarm the vehicle
        vehicle_name (str, optional): Name of the vehicle to send this command to

    Returns:
        bool: Success
    """
    return call(c, "armDisarm", arm, vehicle_name)
end

function simPause(c::VehicleClient, is_paused::Bool)
    """
    Pauses simulation

    Args:
        is_paused (bool): True to pause the simulation, False to release
    """
    call(c, "simPause", is_paused)
end

function simIsPause(c::VehicleClient)
    """
    Returns true if the simulation is paused

    Returns:
        bool: If the simulation is paused
    """
    return call(c, "simIsPaused")
end

function simContinueForTime(c::VehicleClient, seconds::Real)
    """
    Continue the simulation for the specified number of seconds

    Args:
        seconds (float): Time to run the simulation for
    """
    call(c, "simContinueForTime", seconds)
end

function simContinueForFrames(c::VehicleClient, frames)
    """
    Continue (or resume if paused) the simulation for the specified number of frames, after which the simulation will be paused.

    Args:
        frames (int): Frames to run the simulation for
    """
    call(c, "simContinueForFrames", frames)
end

function getHomeGeoPoint(c::VehicleClient, vehicle_name = "")
    """
    Get the Home location of the vehicle

    Args:
        vehicle_name (str, optional): Name of vehicle to get home location of

    Returns:
        GeoPoint: Home location of the vehicle
    """
    msg = call(c, "getHomeGeoPoint", vehicle_name)
    return MsgPack.from_msgpack(GeoPoint, msg)
end


#camera control
#simGetImage returns compressed png in array of bytes
#image_type uses one of the ImageType members
function simGetImage(c::VehicleClient, camera_name::Union{String,Int}, image_type::ImageType, vehicle_name::String="", external::Bool=false)
    """
    Get a single image
    Returns bytes of png format image which can be dumped into abinary file to create .png image
    `string_to_uint8_array()` can be used to convert into Numpy unit8 array
    See https://microsoft.github.io/AirSim/image_apis/ for details
    Args:
        camera_name (str): Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        image_type (ImageType): Type of image required
        vehicle_name (str, optional): Name of the vehicle with the camera
        external (bool, optional): Whether the camera is an External Camera
    Returns:
        Binary string literal of compressed png image
    """

    #because this method returns std::vector < uint8>, msgpack decides to encode it as a string unfortunately.
    result = call(c, "simGetImage", camera_name, image_type.property, vehicle_name, external)
    if result == "" || result == "\0"
        return nothing
    end

    return result
end

#camera control
#simGetImage returns compressed png in array of bytes
#image_type uses one of the ImageType members
function simGetImages(c::VehicleClient, requests::Vector{ImageRequest}, vehicle_name::String="", external::Bool=false)
    """
    Get multiple images

    See https://microsoft.github.io/AirSim/image_apis/ for details and examples

    Args:
        requests (list[ImageRequest]): Images required
        vehicle_name (str, optional): Name of vehicle associated with the camera
        external (bool, optional): Whether the camera is an External Camera

    Returns:
        list[ImageResponse]:
    """
    responses_raw = call(c, "simGetImages", requests, vehicle_name, external)
    return [response_raw for response_raw in responses_raw]
end

