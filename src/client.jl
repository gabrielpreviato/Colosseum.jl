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

    If false (which is functionault) then API calls would be ignored. After a successful call to `enableApiControl`, `isApiControlEnabled` should return true.

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


function confirmConnection(c::VehicleClient)
    """
    Checks state of connection every 1 sec and reports it in Console so user can see the progress for connection.
    """
    if ping(c)
        println("Connected!")
    else
        println("Ping returned false!")
    end
    server_ver = getServerVersion(c)
    client_ver = getClientVersion(c)
    server_min_ver = getMinRequiredServerVersion(c)
    client_min_ver = getMinRequiredClientVersion(c)

    ver_info = "Client Ver: $(client_ver) (Min Req: $client_min_ver), Server Ver: $server_ver (Min Req: $server_min_ver)"

    if server_ver < server_min_ver
        println(Base.stderr, ver_info)
        println("AirSim server is of older version and not supported by this client. Please upgrade!")
    elseif client_ver < client_min_ver
        println(Base.stderr, ver_info)
        println("AirSim client is of older version and not supported by this server. Please upgrade!")
    else
        println(ver_info)
    end
    println("")
end

function simSetLightIntensity(c::VehicleClient, light_name::String, intensity::Real)
    """
    Change intensity of named light

    Args:
        light_name (String): Name of light to change
        intensity (Real): New intensity value

    Returns:
        bool: True if successful, otherwise False
    """
    return call(c, "simSetLightIntensity", light_name, intensity)
end

function simSwapTextures(c::VehicleClient, tags, tex_id = 0, component_id = 0, material_id = 0)
    """
    Runtime Swap Texture API

    See https://microsoft.github.io/AirSim/retexturing/ for details

    Args:
        tags (str): string of "," or ", " delimited tags to identify on which actors to perform the swap
        tex_id (int, optional): indexes the array of textures assigned to each actor undergoing a swap

                                If out-of-bounds for some object's texture set, it will be taken modulo the number of textures that were available
        component_id (int, optional):
        material_id (int, optional):

    Returns:
        list[str]: List of objects which matched the provided tags and had the texture swap perfomed
    """
    return call(c, "simSwapTextures", tags, tex_id, component_id, material_id)
end

function simSetObjectMaterial(c::VehicleClient, object_name, material_name, component_id = 0)
    """
    Runtime Swap Texture API
    See https://microsoft.github.io/AirSim/retexturing/ for details
    Args:
        object_name (str): name of object to set material for
        material_name (str): name of material to set for object
        component_id (int, optional) : index of material elements

    Returns:
        bool: True if material was set
    """
    return call(c, "simSetObjectMaterial", object_name, material_name, component_id)
end

function simSetObjectMaterialFromTexture(c::VehicleClient, object_name, texture_path, component_id = 0)
    """
    Runtime Swap Texture API
    See https://microsoft.github.io/AirSim/retexturing/ for details
    Args:
        object_name (str): name of object to set material for
        texture_path (str): path to texture to set for object
        component_id (int, optional) : index of material elements

    Returns:
        bool: True if material was set
    """
    return call(c, "simSetObjectMaterialFromTexture", object_name, texture_path, component_id)
end

# time-of-day control
#time - of - day control
function simSetTimeOfDay(c::VehicleClient, is_enabled::Bool, start_datetime::String="", is_start_datetime_dst::Bool=false, celestial_clock_speed::Int=1, update_interval_secs::Int=60, move_sun::Bool=true)
    """
    Control the position of Sun in the environment

    Sun's position is computed using the coordinates specified in `OriginGeopoint` in settings for the date-time specified in the argument,
    else if the string is empty, current date & time is used

    Args:
        is_enabled (bool): True to enable time-of-day effect, False to reset the position to original
        start_datetime (str, optional): Date & Time in %Y-%m-%d %H:%M:%S format, e.g. `2018-02-12 15:20:00`
        is_start_datetime_dst (bool, optional): True to adjust for Daylight Savings Time
        celestial_clock_speed (float, optional): Run celestial clock faster or slower than simulation clock
                                                E.g. Value 100 means for every 1 second of simulation clock, Sun's position is advanced by 100 seconds
                                                so Sun will move in sky much faster
        update_interval_secs (float, optional): Interval to update the Sun's position
        move_sun (bool, optional): Whether or not to move the Sun
    """
    call(c, "simSetTimeOfDay", is_enabled, start_datetime, is_start_datetime_dst, celestial_clock_speed, update_interval_secs, move_sun)
end

#weather
function simEnableWeather(c::VehicleClient, enable::Bool)
    """
    Enable Weather effects. Needs to be called before using `simSetWeatherParameter` API

    Args:
        enable (bool): True to enable, False to disable
    """
    call(c, "simEnableWeather", enable)
end

function simSetWeatherParameter(c::VehicleClient, param, val::Real)
    """
    Enable various weather effects

    Args:
        param (WeatherParameter): Weather effect to be enabled
        val (float): Intensity of the effect, Range 0-1
    """
    call(c, "simSetWeatherParameter", param, val)
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

