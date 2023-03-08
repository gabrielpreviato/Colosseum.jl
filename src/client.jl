using Sockets
using Serialization
using MsgPack

using Colosseum

RESPONSE = 0x01

abstract type AbstractVehicleClient
end
struct VehicleClient <: AbstractVehicleClient
    client::TCPSocket
end

function VehicleClient(ip::String="127.0.0.1", port::Int=41451)
    client = connect(ip, port)

    VehicleClient(client)
end

function call(c::AbstractVehicleClient, method::String, args...; idx::UInt8=0x00)
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

"""
        reset(c::AbstractVehicleClient)
    
    Reset the vehicle to its original starting state

    Note that you must call `enableApiControl` and `armDisarm` again after the call to reset
    """
function reset(c::AbstractVehicleClient)::Nothing
    
    call(c, "reset")
end

"""
        ping(c::AbstractVehicleClient)

    If connection is established then this call will return true otherwise it will be blocked until timeout
    """
function ping(c::AbstractVehicleClient)::Bool
    
    call(c, "ping")
end

function getClientVersion(c::AbstractVehicleClient)
        return 1 # sync with C++ client
end

function getServerVersion(c::AbstractVehicleClient)
    return call(c, "getServerVersion")
end

function getMinRequiredServerVersion(c::AbstractVehicleClient)
    return 1 # sync with C++ client
end

"""
    Enables || disables API control for vehicle corresponding to vehicle_name

    Args:
        is_enabled (bool) True to enable, false to disable API control
        vehicle_name (str, optional) Name of the vehicle to send this command to
        """
function getMinRequiredClientVersion(c::AbstractVehicleClient)
    
    return call(c, "getMinRequiredClientVersion")
end

# Basic flight control
function enableApiControl(c::AbstractVehicleClient, is_enabled::Bool, vehicle_name::String="")
    call(c, "enableApiControl", is_enabled, vehicle_name)
end

"""
    Returns true if API control is established.

    If false (which is functionault) then API calls would be ignored. After a successful call to `enableApiControl`, `isApiControlEnabled` should return true.

    Args:
        vehicle_name (str, optional) Name of the vehicle

    Returns:
        bool: If API control is enabled
    """
function isApiControlEnabled(c::AbstractVehicleClient, vehicle_name::String="")
    
    call(c, "isApiControlEnabled", vehicle_name)
end

"""
    Arms || disarms vehicle

    Args:
        arm (bool) True to arm, false to disarm the vehicle
        vehicle_name (str, optional) Name of the vehicle to send this command to

    Returns:
        bool: Success
    """
function armDisarm(c::AbstractVehicleClient, arm::Bool, vehicle_name::String="")
    
    return call(c, "armDisarm", arm, vehicle_name)
end

"""
    Pauses simulation

    Args:
        is_paused (bool) True to pause the simulation, false to release
    """
function simPause(c::AbstractVehicleClient, is_paused::Bool)
    
    call(c, "simPause", is_paused)
end

"""
    Returns true if the simulation is paused

    Returns:
        bool: If the simulation is paused
    """
function simIsPause(c::AbstractVehicleClient)
    
    return call(c, "simIsPaused")
end

"""
    Continue the simulation for the specified number of seconds

    Args:
        seconds (float) Time to run the simulation for
    """
function simContinueForTime(c::AbstractVehicleClient, seconds::Real)
    
    call(c, "simContinueForTime", seconds)
end

"""
    Continue (or resume if paused) the simulation for the specified number of frames, after which the simulation will be paused.

    Args:
        frames (int) Frames to run the simulation for
    """
function simContinueForFrames(c::AbstractVehicleClient, frames)
    
    call(c, "simContinueForFrames", frames)
end

"""
    Get the Home location of the vehicle

    Args:
        vehicle_name (str, optional) Name of vehicle to get home location of

    Returns:
        GeoPoint: Home location of the vehicle
    """
function getHomeGeoPoint(c::AbstractVehicleClient, vehicle_name::String="")
    
    msg = call(c, "getHomeGeoPoint", vehicle_name)
    return MsgPack.from_msgpack(GeoPoint, msg)
end


"""
    Checks state of connection every 1 sec and reports it in Console so user can see the progress for connection.
    """
function confirmConnection(c::AbstractVehicleClient)
    
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

"""
    Change intensity of named light

    Args:
        light_name (String) Name of light to change
        intensity (Real) New intensity value

    Returns:
        bool: True if successful, otherwise false
    """
function simSetLightIntensity(c::AbstractVehicleClient, light_name::String, intensity::Real)
    
    return call(c, "simSetLightIntensity", light_name, intensity)
end

"""
    Runtime Swap Texture API

    See https://microsoft.github.io/AirSim/retexturing/ for details

    Args:
        tags (str) string of "," || ", " delimited tags to identify on which actors to perform the swap
        tex_id (int, optional) indexes the array of textures assigned to each actor undergoing a swap

                                If out-of-bounds for some object's texture set, it will be taken modulo the number of textures that were available
        component_id (int, optional)
        material_id (int, optional)

    Returns:
        list[str]: List of objects which matched the provided tags and had the texture swap perfomed
    """
function simSwapTextures(c::AbstractVehicleClient, tags, tex_id=0, component_id=0, material_id=0)
    
    return call(c, "simSwapTextures", tags, tex_id, component_id, material_id)
end

"""
    Runtime Swap Texture API
    See https://microsoft.github.io/AirSim/retexturing/ for details
    Args:
        object_name (str) name of object to set material for
        material_name (str) name of material to set for object
        component_id (int, optional) : index of material elements

    Returns:
        bool: True if material was set
    """
function simSetObjectMaterial(c::AbstractVehicleClient, object_name, material_name, component_id=0)
    
    return call(c, "simSetObjectMaterial", object_name, material_name, component_id)
end

"""
    Runtime Swap Texture API
    See https://microsoft.github.io/AirSim/retexturing/ for details
    Args:
        object_name (str) name of object to set material for
        texture_path (str) path to texture to set for object
        component_id (int, optional) : index of material elements

    Returns:
        bool: True if material was set
    """
function simSetObjectMaterialFromTexture(c::AbstractVehicleClient, object_name, texture_path, component_id=0)
    
    return call(c, "simSetObjectMaterialFromTexture", object_name, texture_path, component_id)
end

# time-of-day control
#time - of - day control
"""
    Control the position of Sun in the environment

    Sun's position is computed using the coordinates specified in `OriginGeopoint` in settings for the date-time specified in the argument,
    else if the string is empty, current date & time is used

    Args:
        is_enabled (bool) True to enable time-of-day effect, false to reset the position to original
        start_datetime (str, optional) Date & Time in %Y-%m-%d %H:%M:%S format, e.g. `2018-02-12 15:20:00`
        is_start_datetime_dst (bool, optional) True to adjust for Daylight Savings Time
        celestial_clock_speed (float, optional) Run celestial clock faster || slower than simulation clock
                                                E.g. Value 100 means for every 1 second of simulation clock, Sun's position is advanced by 100 seconds
                                                so Sun will move in sky much faster
        update_interval_secs (float, optional) Interval to update the Sun's position
        move_sun (bool, optional) Whether || not to move the Sun
    """
function simSetTimeOfDay(c::AbstractVehicleClient, is_enabled::Bool, start_datetime::String="", is_start_datetime_dst::Bool=false, celestial_clock_speed::Int=1, update_interval_secs::Int=60, move_sun::Bool=true)
    
    call(c, "simSetTimeOfDay", is_enabled, start_datetime, is_start_datetime_dst, celestial_clock_speed, update_interval_secs, move_sun)
end

#weather
"""
    Enable Weather effects. Needs to be called before using `simSetWeatherParameter` API

    Args:
        enable (bool) True to enable, false to disable
    """
function simEnableWeather(c::AbstractVehicleClient, enable::Bool)
    
    call(c, "simEnableWeather", enable)
end

"""
    Enable various weather effects

    Args:
        param (WeatherParameter) Weather effect to be enabled
        val (float) Intensity of the effect, Range 0-1
    """
function simSetWeatherParameter(c::AbstractVehicleClient, param, val::Real)
    
    call(c, "simSetWeatherParameter", param, val)
end

#camera control
#simGetImage returns compressed png in array of bytes
#image_type uses one of the ImageType members
"""
    Get a single image
    Returns bytes of png format image which can be dumped into abinary file to create .png image
    `string_to_uint8_array()` can be used to convert into Numpy unit8 array
    See https://microsoft.github.io/AirSim/image_apis/ for details
    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        image_type (ImageType) Type of image required
        vehicle_name (str, optional) Name of the vehicle with the camera
        external (bool, optional) Whether the camera is an External Camera
    Returns:
        Binary string literal of compressed png image
    """
function simGetImage(c::AbstractVehicleClient, camera_name::Union{String,Int}, image_type::ImageType, vehicle_name::String="", external::Bool=false)
    #because this method returns std::vector < uint8>, msgpack decides to encode it as a string unfortunately.
    result = call(c, "simGetImage", camera_name, image_type, vehicle_name, external)
    if result == "" || result == "\0"
        return nothing
    end

    return result
end

#camera control
#simGetImage returns compressed png in array of bytes
#image_type uses one of the ImageType members
"""
    Get multiple images

    See https://microsoft.github.io/AirSim/image_apis/ for details and examples

    Args:
        requests (list[ImageRequest]) Images required
        vehicle_name (str, optional) Name of vehicle associated with the camera
        external (bool, optional) Whether the camera is an External Camera

    Returns:
        list[ImageResponse]:
    """
function simGetImages(c::AbstractVehicleClient, requests::Vector{ImageRequest}, vehicle_name::String="", external::Bool=false)
    responses_raw = call(c, "simGetImages", requests, vehicle_name, external)
    return [response_raw for response_raw in responses_raw]
end


#CinemAirSim
function simGetPresetLensSettings(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    result = call(c, "simGetPresetLensSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
    return result

end

function simGetLensSettings(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    result = call(c, "simGetLensSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
return result
end

function simSetPresetLensSettings(c::AbstractVehicleClient, preset_lens_settings, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simSetPresetLensSettings", preset_lens_settings, camera_name, vehicle_name, external)
end

function simGetPresetFilmbackSettings(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    result = call(c, "simGetPresetFilmbackSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
    return result

end

function simSetPresetFilmbackSettings(c::AbstractVehicleClient, preset_filmback_settings, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simSetPresetFilmbackSettings", preset_filmback_settings, camera_name, vehicle_name, external)
end

function simGetFilmbackSettings(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    result = call(c, "simGetFilmbackSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
    return result
end

function simSetFilmbackSettings(c::AbstractVehicleClient, sensor_width, sensor_height, camera_name::String, vehicle_name::String="", external::Bool=false)  
    return call(c, "simSetFilmbackSettings", sensor_width, sensor_height, camera_name, vehicle_name, external)
end

function simGetFocalLength(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    return call(c, "simGetFocalLength", camera_name, vehicle_name, external)
end

function simSetFocalLength(c::AbstractVehicleClient, focal_length, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simSetFocalLength", focal_length, camera_name, vehicle_name, external)
end

function simEnableManualFocus(c::AbstractVehicleClient, enable, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simEnableManualFocus", enable, camera_name, vehicle_name, external)
end

function simGetFocusDistance(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    return call(c, "simGetFocusDistance", camera_name, vehicle_name, external)
end

function simSetFocusDistance(c::AbstractVehicleClient, focus_distance, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simSetFocusDistance", focus_distance, camera_name, vehicle_name, external)
end

function simGetFocusAperture(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    return call(c, "simGetFocusAperture", camera_name, vehicle_name, external)
end

function simSetFocusAperture(c::AbstractVehicleClient, focus_aperture, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simSetFocusAperture", focus_aperture, camera_name, vehicle_name, external)
end

function simEnableFocusPlane(c::AbstractVehicleClient, enable, camera_name::String, vehicle_name::String="", external::Bool=false)  
    call(c, "simEnableFocusPlane", enable, camera_name, vehicle_name, external)
end

function simGetCurrentFieldOfView(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)  
    return call(c, "simGetCurrentFieldOfView", camera_name, vehicle_name, external) 
end
#End CinemAirSim

"""
    Returns whether the target point is visible from the perspective of the inputted vehicle

    Args:
        point (GeoPoint) target point
        vehicle_name (str, optional) Name of vehicle

    Returns:
        [bool]: Success
    """
function simTestLineOfSightToPoint(c::AbstractVehicleClient, point, vehicle_name::String="")
    
    return call(c, "simTestLineOfSightToPoint", point, vehicle_name)
end

"""
    Returns whether the target point is visible from the perspective of the source point

    Args:
        point1 (GeoPoint) source point
        point2 (GeoPoint) target point

    Returns:
        [bool]: Success
    """
function simTestLineOfSightBetweenPoints(c::AbstractVehicleClient, point1, point2)
    
    return call(c, "simTestLineOfSightBetweenPoints", point1, point2)
end

"""
    Returns a list of GeoPoints representing the minimum and maximum extents of the world

    Returns:
        list[GeoPoint]
    """
function simGetWorldExtents(c::AbstractVehicleClient)
    
    responses_raw = call(c, "simGetWorldExtents")
    return [GeoPoint.from_msgpack(response_raw) for response_raw in responses_raw]
end

"""
    Allows the client to execute a command in Unreal's native console, via an API.
    Affords access to the countless built-in commands such as "stat unit", "stat fps", "open [map]", adjust any config settings, etc. etc.
    Allows the user to create bespoke APIs very easily, by adding a custom event to the level blueprint, and then calling the console command "ce MyEventName [args]". No recompilation of AirSim needed!

    Args:
        command ([string]) Desired Unreal Engine Console command to run

    Returns:
        [bool]: Success
    """
function simRunConsoleCommand(c::AbstractVehicleClient, command)
    
    return call(c, "simRunConsoleCommand", command)
end

#gets the static meshes in the unreal scene
"""
    Returns the static meshes that make up the scene

    See https://microsoft.github.io/AirSim/meshes/ for details and how to use this

    Returns:
        list[MeshPositionVertexBuffersResponse]:
    """
function simGetMeshPositionVertexBuffers(c::AbstractVehicleClient)
    
    responses_raw = call(c, "simGetMeshPositionVertexBuffers")
    return [MeshPositionVertexBuffersResponse.from_msgpack(response_raw) for response_raw in responses_raw]
end

"""
    Args:
        vehicle_name (str, optional) Name of the Vehicle to get the info of

    Returns:
        CollisionInfo:
    """
function simGetCollisionInfo(c::AbstractVehicleClient, vehicle_name::String="")
    
    return CollisionInfo.from_msgpack(call(c, "simGetCollisionInfo", vehicle_name))
end

"""
    Set the pose of the vehicle

    If you don't want to change position (or orientation) then just set components of position (or orientation) to floating point nan values

    Args:
        pose (Pose) Desired Pose pf the vehicle
        ignore_collision (bool) Whether to ignore any collision || not
        vehicle_name (str, optional) Name of the vehicle to move
    """
function simSetVehiclePose(c::AbstractVehicleClient, pose, ignore_collision, vehicle_name::String="")
    
    call(c, "simSetVehiclePose", pose, ignore_collision, vehicle_name)
end

"""
    The position inside the returned Pose is in the frame of the vehicle's starting point

    Args:
        vehicle_name (str, optional) Name of the vehicle to get the Pose of

    Returns:
        Pose:
    """
function simGetVehiclePose(c::AbstractVehicleClient, vehicle_name::String="")
    
    pose = call(c, "simGetVehiclePose", vehicle_name)
    return Pose.from_msgpack(pose)
end

"""
    Modify the color and thickness of the line when Tracing is enabled

    Tracing can be enabled by pressing T in the Editor || setting `EnableTrace` to `True` in the Vehicle Settings

    Args:
        color_rgba (list) desired RGBA values from 0.0 to 1.0
        thickness (float, optional) Thickness of the line
        vehicle_name (string, optional) Name of the vehicle to set Trace line values for
    """
function simSetTraceLine(c::AbstractVehicleClient, color_rgba, thickness=1.0, vehicle_name::String="")
    
    call(c, "simSetTraceLine", color_rgba, thickness, vehicle_name)

end

"""
    The position inside the returned Pose is in the world frame

    Args:
        object_name (str) Object to get the Pose of

    Returns:
        Pose:
    """
function simGetObjectPose(c::AbstractVehicleClient, object_name)
    
    pose = call(c, "simGetObjectPose", object_name)
    return Pose.from_msgpack(pose)

end

"""
    Set the pose of the object(actor) in the environment

    The specified actor must have Mobility set to movable, otherwise there will be unend
functionined behaviour.
    See https://www.unrealengine.com/en-US/blog/moving-physical-objects for details on how to set Mobility and the effect of Teleport parameter

    Args:
        object_name (str) Name of the object(actor) to move
        pose (Pose) Desired Pose of the object
        teleport (bool, optional) Whether to move the object immediately without affecting their velocity

    Returns:
        bool: If the move was successful
    """
function simSetObjectPose(c::AbstractVehicleClient, object_name, pose, teleport=True)
    
    return call(c, "simSetObjectPose", object_name, pose, teleport)

end

"""
    Gets scale of an object in the world

    Args:
        object_name (str) Object to get the scale of

    Returns:
        airsim.Vector3r: Scale
    """
function simGetObjectScale(c::AbstractVehicleClient, object_name)
    
    scale = call(c, "simGetObjectScale", object_name)
    return Vector3r.from_msgpack(scale)

end

"""
    Sets scale of an object in the world

    Args:
        object_name (str) Object to set the scale of
        scale_vector (airsim.Vector3r) Desired scale of object

    Returns:
        bool: True if scale change was successful
    """
function simSetObjectScale(c::AbstractVehicleClient, object_name, scale_vector)
    
    return call(c, "simSetObjectScale", object_name, scale_vector)

end

"""
    Lists the objects present in the environment

    end
functionault behaviour is to list all objects, regex can be used to return smaller list of matching objects || actors

    Args:
        name_regex (str, optional) String to match actor names against, e.g. "Cylinder.*"

    Returns:
        list[str]: List containing all the names
    """
function simListSceneObjects(c::AbstractVehicleClient, name_regex=".*")
    
    return call(c, "simListSceneObjects", name_regex)

end

"""
    Loads a level specified by its name

    Args:
        level_name (str) Name of the level to load

    Returns:
        bool: True if the level was successfully loaded
    """
function simLoadLevel(c::AbstractVehicleClient, level_name)
    
    return call(c, "simLoadLevel", level_name)

end

"""
    Lists all the assets present in the Asset Registry

    Returns:
        list[str]: Names of all the assets
    """
function simListAssets(c::AbstractVehicleClient)
    
    return call(c, "simListAssets")

end

"""Spawned selected object in the world

    Args:
        object_name (str) Desired name of new object
        asset_name (str) Name of asset(mesh) in the project database
        pose (airsim.Pose) Desired pose of object
        scale (airsim.Vector3r) Desired scale of object
        physics_enabled (bool, optional) Whether to enable physics for the object
        is_blueprint (bool, optional) Whether to spawn a blueprint || an actor

    Returns:
        str: Name of spawned object, in case it had to be modified
    """
function simSpawnObject(c::AbstractVehicleClient, object_name, asset_name, pose, scale, physics_enabled=false, is_blueprint=false)
    
    return call(c, "simSpawnObject", object_name, asset_name, pose, scale, physics_enabled, is_blueprint)

end

"""Removes selected object from the world

    Args:
        object_name (str) Name of object to be removed

    Returns:
        bool: True if object is queued up for removal
    """
function simDestroyObject(c::AbstractVehicleClient, object_name)
    
    return call(c, "simDestroyObject", object_name)

end

"""
    Set segmentation ID for specific objects

    See https://microsoft.github.io/AirSim/image_apis/#segmentation for details

    Args:
        mesh_name (str) Name of the mesh to set the ID of (supports regex)
        object_id (int) Object ID to be set, range 0-255

                            RBG values for IDs can be seen at https://microsoft.github.io/AirSim/seg_rgbs.txt
        is_name_regex (bool, optional) Whether the mesh name is a regex

    Returns:
        bool: If the mesh was found
    """
function simSetSegmentationObjectID(c::AbstractVehicleClient, mesh_name, object_id, is_name_regex=false)
    
    return call(c, "simSetSegmentationObjectID", mesh_name, object_id, is_name_regex)

end

"""
    Returns Object ID for the given mesh name

    Mapping of Object IDs to RGB values can be seen at https://microsoft.github.io/AirSim/seg_rgbs.txt

    Args:
        mesh_name (str) Name of the mesh to get the ID of
    """
function simGetSegmentationObjectID(c::AbstractVehicleClient, mesh_name)
    
    return call(c, "simGetSegmentationObjectID", mesh_name)

end

"""
    Add mesh name to detect in wild card format

    For example: simAddDetectionFilterMeshName("Car_*") will detect all instance named "Car_*"

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        image_type (ImageType) Type of image required
        mesh_name (str) mesh name in wild card format
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera

    """
function simAddDetectionFilterMeshName(c::AbstractVehicleClient, camera_name::String, image_type::ImageType, mesh_name, vehicle_name::String="", external::Bool=false)
    
    call(c, "simAddDetectionFilterMeshName", camera_name, image_type, mesh_name, vehicle_name, external)

end

"""
    Set detection radius for all cameras

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        image_type (ImageType) Type of image required
        radius_cm (int) Radius in [cm]
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera
    """
function simSetDetectionFilterRadius(c::AbstractVehicleClient, camera_name::String, image_type::ImageType, radius_cm, vehicle_name::String="", external::Bool=false)
    
    call(c, "simSetDetectionFilterRadius", camera_name, image_type, radius_cm, vehicle_name, external)

end

"""
    Clear all mesh names from detection filter

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        image_type (ImageType) Type of image required
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera

    """
function simClearDetectionMeshNames(c::AbstractVehicleClient, camera_name::String, image_type::ImageType, vehicle_name::String="", external::Bool=false)
    
    call(c, "simClearDetectionMeshNames", camera_name, image_type, vehicle_name, external)

end

"""
    Get current detections

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        image_type (ImageType) Type of image required
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera

    Returns:
        DetectionInfo array
    """
function simGetDetections(c::AbstractVehicleClient, camera_name::String, image_type::ImageType, vehicle_name::String="", external::Bool=false)
    
    responses_raw = call(c, "simGetDetections", camera_name, image_type, vehicle_name, external)
    return [DetectionInfo.from_msgpack(response_raw) for response_raw in responses_raw]

end

"""
    Prints the specified message in the simulator's window.

    If message_param is supplied, then it's printed next to the message and in that case if this API is called with same message value
    but different message_param again then previous line is overwritten with new line (instead of API creating new line on display).

    For example, `simPrintLogMessage("Iteration: ", to_string(i))` keeps updating same line on display when API is called with different values of i.
    The valid values of severity parameter is 0 to 3 inclusive that corresponds to different colors.

    Args:
        message (str) Message to be printed
        message_param (str, optional) Parameter to be printed next to the message
        severity (int, optional) Range 0-3, inclusive, corresponding to the severity of the message
    """
function simPrintLogMessage(c::AbstractVehicleClient, message, message_param="", severity=0)
    
    call(c, "simPrintLogMessage", message, message_param, severity)

end

"""
    Get details about the camera

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera

    Returns:
        CameraInfo:
    """
function simGetCameraInfo(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)
    
#TODO : below str() conversion is only needed for legacy reason and should be removed in future
    return CameraInfo.from_msgpack(call(c, "simGetCameraInfo", str(camera_name), vehicle_name, external))

end

"""
    Get camera distortion parameters

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera

    Returns:
        List (float) List of distortion parameter values corresponding to K1, K2, K3, P1, P2 respectively.
    """
function simGetDistortionParams(c::AbstractVehicleClient, camera_name::String, vehicle_name::String="", external::Bool=false)
    

    return call(c, "simGetDistortionParams", str(camera_name), vehicle_name, external)

end

"""
    Set camera distortion parameters

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        distortion_params (dict) Dictionary of distortion param names and corresponding values
                                    {"K1": 0.0, "K2": 0.0, "K3": 0.0, "P1": 0.0, "P2": 0.0}
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera
    """
function simSetDistortionParams(c::AbstractVehicleClient, camera_name::String, distortion_params, vehicle_name::String="", external::Bool=false)
    

    for (param_name, value) in items(distortion_params)
        c::AbstractVehicleClient.simSetDistortionParam(camera_name, param_name, value, vehicle_name, external)
    end
end

"""
    Set single camera distortion parameter

    Args:
        camera_name (str) Name of the camera, for backwards compatibility, ID numbers such as 0,1,etc. can also be used
        param_name (str) Name of distortion parameter
        value (float) Value of distortion parameter
        vehicle_name (str, optional) Vehicle which the camera is associated with
        external (bool, optional) Whether the camera is an External Camera
    """
function simSetDistortionParam(c::AbstractVehicleClient, camera_name::String, param_name, value, vehicle_name::String="", external::Bool=false)
    
    call(c, "simSetDistortionParam", str(camera_name), param_name, value, vehicle_name, external)
end

"""
    - Control the pose of a selected camera

    Args:
        camera_name (str) Name of the camera to be controlled
        pose (Pose) Pose representing the desired position and orientation of the camera
        vehicle_name (str, optional) Name of vehicle which the camera corresponds to
        external (bool, optional) Whether the camera is an External Camera
    """
function simSetCameraPose(c::AbstractVehicleClient, camera_name::String, pose, vehicle_name::String="", external::Bool=false)
    
#TODO : below str() conversion is only needed for legacy reason and should be removed in future
    call(c, "simSetCameraPose", str(camera_name), pose, vehicle_name, external)
end

"""
    - Control the field of view of a selected camera

    Args:
        camera_name (str) Name of the camera to be controlled
        fov_degrees (float) Value of field of view in degrees
        vehicle_name (str, optional) Name of vehicle which the camera corresponds to
        external (bool, optional) Whether the camera is an External Camera
    """
function simSetCameraFov(c::AbstractVehicleClient, camera_name::String, fov_degrees, vehicle_name::String="", external::Bool=false)
    
#TODO : below str() conversion is only needed for legacy reason and should be removed in future
    call(c, "simSetCameraFov", str(camera_name), fov_degrees, vehicle_name, external)
end






"""
Get Ground truth kinematics of the vehiclevehicle_name=""

The position inside the returned KinematicsState is in the frame of the vehicle's starting point

Args:
    vehicle_name (str, optional): Name of the vehicle

Returns:
    KinematicsState: Ground truth of the vehicle
"""
function simGetGroundTruthKinematics(c::AbstractVehicleClient, vehicle_name::String="")
    kinematics_state = call(c, "simGetGroundTruthKinematics", vehicle_name)
    return KinematicsState.from_msgpack(kinematics_state)
end

"""
Set the kinematics state of the vehicle

If you don't want to change position (or orientation) then just set components of position (or orientation) to floating point nan values

Args:
    state (KinematicsState): Desired Pose pf the vehicle
    ignore_collision (bool): Whether to ignore any collision or not
    vehicle_name (str, optional): Name of the vehicle to move
"""
function simSetKinematics(c::AbstractVehicleClient, state, ignore_collision, vehicle_name::String="")
    call(c, "simSetKinematics", state, ignore_collision, vehicle_name)
end

"""
Get ground truth environment state

The position inside the returned EnvironmentState is in the frame of the vehicle's starting point

Args:
    vehicle_name (str, optional): Name of the vehicle

Returns:
    EnvironmentState: Ground truth environment state
"""
function simGetGroundTruthEnvironment(c::AbstractVehicleClient, vehicle_name::String="")
    env_state = call(c, "simGetGroundTruthEnvironment", vehicle_name)
    return EnvironmentState.from_msgpack(env_state)
end


#sensor APIsend

"""
Args:
    imu_name (str, optional): Name of IMU to get data from, specified in settings.json
    vehicle_name (str, optional): Name of vehicle to which the sensor corresponds to

Returns:
    ImuData:
"""
function getImuData(c::AbstractVehicleClient, imu_name="', vehicle_name='")
return ImuData.from_msgpack(call(c, "getImuData", imu_name, vehicle_name))
end

"""
Args:
    barometer_name (str, optional): Name of Barometer to get data from, specified in settings.json
    vehicle_name (str, optional): Name of vehicle to which the sensor corresponds to

Returns:
    BarometerData:
"""
function getBarometerData(c::AbstractVehicleClient, barometer_name="', vehicle_name='")
return BarometerData.from_msgpack(call(c, "getBarometerData", barometer_name, vehicle_name))
end

"""
Args:
    magnetometer_name (str, optional): Name of Magnetometer to get data from, specified in settings.json
    vehicle_name (str, optional): Name of vehicle to which the sensor corresponds to

Returns:
    MagnetometerData:
"""
function getMagnetometerData(c::AbstractVehicleClient, magnetometer_name="', vehicle_name='")
return MagnetometerData.from_msgpack(call(c, "getMagnetometerData", magnetometer_name, vehicle_name))
end

"""
Args:
    gps_name (str, optional): Name of GPS to get data from, specified in settings.json
    vehicle_name (str, optional): Name of vehicle to which the sensor corresponds to

Returns:
    GpsData:
"""
function getGpsData(c::AbstractVehicleClient, gps_name="', vehicle_name='")
return GpsData.from_msgpack(call(c, "getGpsData", gps_name, vehicle_name))
end

"""
Args:
    distance_sensor_name (str, optional): Name of Distance Sensor to get data from, specified in settings.json
    vehicle_name (str, optional): Name of vehicle to which the sensor corresponds to

Returns:
    DistanceSensorData:
"""
function getDistanceSensorData(c::AbstractVehicleClient, distance_sensor_name="', vehicle_name='")
return DistanceSensorData.from_msgpack(call(c, "getDistanceSensorData", distance_sensor_name, vehicle_name))
end

"""
Args:
    lidar_name (str, optional): Name of Lidar to get data from, specified in settings.json
    vehicle_name (str, optional): Name of vehicle to which the sensor corresponds to

Returns:
    LidarData:
"""
function getLidarData(c::AbstractVehicleClient, lidar_name="', vehicle_name='")
return LidarData.from_msgpack(call(c, "getLidarData", lidar_name, vehicle_name))
end

"""
NOTE: Deprecated API, use `getLidarData()` API instead
Returns Segmentation ID of each point's collided object in the last Lidar update

Args:
    lidar_name (str, optional): Name of Lidar sensor
    vehicle_name (str, optional): Name of the vehicle wth the sensor

Returns:
    list[int]: Segmentation IDs of the objects
"""
function simGetLidarSegmentation(c::AbstractVehicleClient, lidar_name="', vehicle_name='")
logging.warning("simGetLidarSegmentation API is deprecated, use getLidarData() API instead")
return self.getLidarData(lidar_name, vehicle_name).segmentation
end

#Plotting APIsend

"""
Clear any persistent markers - those plotted with setting `is_persistent=True` in the APIs below
"""
function simFlushPersistentMarkers(c::AbstractVehicleClient)
call(c, "simFlushPersistentMarkers")
end

"""
Plot a list of 3D points in World NED frame

Args:
    points (list[Vector3r]): List of Vector3r objects
    color_rgba (list, optional): desired RGBA values from 0.0 to 1.0
    size (float, optional): Size of plotted point
    duration (float, optional): Duration (seconds) to plot for
    is_persistent (bool, optional): If set to True, the desired object will be plotted for infinite time.
"""
function simPlotPoints(c::AbstractVehicleClient, points, color_rgba=[1.0, 0.0, 0.0, 1.0], size=10.0, duration=-1.0, is_persistent=false)
call(c, "simPlotPoints", points, color_rgba, size, duration, is_persistent)
end

"""
Plots a line strip in World NED frame, defined from points[0] to points[1], points[1] to points[2], ... , points[n-2] to points[n-1]

Args:
    points (list[Vector3r]): List of 3D locations of line start and end points, specified as Vector3r objects
    color_rgba (list, optional): desired RGBA values from 0.0 to 1.0
    thickness (float, optional): Thickness of line
    duration (float, optional): Duration (seconds) to plot for
    is_persistent (bool, optional): If set to True, the desired object will be plotted for infinite time.
"""
function simPlotLineStrip(c::AbstractVehicleClient, points, color_rgba=[1.0, 0.0, 0.0, 1.0], thickness=5.0, duration=-1.0, is_persistent=false)
call(c, "simPlotLineStrip", points, color_rgba, thickness, duration, is_persistent)
end

"""
Plots a line strip in World NED frame, defined from points[0] to points[1], points[2] to points[3], ... , points[n-2] to points[n-1]

Args:
    points (list[Vector3r]): List of 3D locations of line start and end points, specified as Vector3r objects. Must be even
    color_rgba (list, optional): desired RGBA values from 0.0 to 1.0
    thickness (float, optional): Thickness of line
    duration (float, optional): Duration (seconds) to plot for
    is_persistent (bool, optional): If set to True, the desired object will be plotted for infinite time.
"""
function simPlotLineList(c::AbstractVehicleClient, points, color_rgba=[1.0, 0.0, 0.0, 1.0], thickness=5.0, duration=-1.0, is_persistent=false)
call(c, "simPlotLineList", points, color_rgba, thickness, duration, is_persistent)
end

"""
Plots a list of arrows in World NED frame, defined from points_start[0] to points_end[0], points_start[1] to points_end[1], ... , points_start[n-1] to points_end[n-1]

Args:
    points_start (list[Vector3r]): List of 3D start positions of arrow start positions, specified as Vector3r objects
    points_end (list[Vector3r]): List of 3D end positions of arrow start positions, specified as Vector3r objects
    color_rgba (list, optional): desired RGBA values from 0.0 to 1.0
    thickness (float, optional): Thickness of line
    arrow_size (float, optional): Size of arrow head
    duration (float, optional): Duration (seconds) to plot for
    is_persistent (bool, optional): If set to True, the desired object will be plotted for infinite time.
"""
function simPlotArrows(c::AbstractVehicleClient, points_start, points_end, color_rgba=[1.0, 0.0, 0.0, 1.0], thickness=5.0, arrow_size=2.0, duration=-1.0, is_persistent=false)
call(c, "simPlotArrows", points_start, points_end, color_rgba, thickness, arrow_size, duration, is_persistent)

end

"""
Plots a list of strings at desired positions in World NED frame.

Args:
    strings (list[String], optional): List of strings to plot
    positions (list[Vector3r]): List of positions where the strings should be plotted. Should be in one-to-one correspondence with the strings' list
    scale (float, optional): Font scale of transform name
    color_rgba (list, optional): desired RGBA values from 0.0 to 1.0
    duration (float, optional): Duration (seconds) to plot for
"""
function simPlotStrings(c::AbstractVehicleClient, strings, positions, scale=5, color_rgba=[1.0, 0.0, 0.0, 1.0], duration=-1.0)
call(c, "simPlotStrings", strings, positions, scale, color_rgba, duration)
end

"""
Plots a list of transforms in World NED frame.

Args:
    poses (list[Pose]): List of Pose objects representing the transforms to plot
    scale (float, optional): Length of transforms' axes
    thickness (float, optional): Thickness of transforms' axes
    duration (float, optional): Duration (seconds) to plot for
    is_persistent (bool, optional): If set to True, the desired object will be plotted for infinite time.
"""
function simPlotTransforms(c::AbstractVehicleClient, poses, scale=5.0, thickness=5.0, duration=-1.0, is_persistent=false)
call(c, "simPlotTransforms", poses, scale, thickness, duration, is_persistent)
end

"""
Plots a list of transforms with their names in World NED frame.

Args:
    poses (list[Pose]): List of Pose objects representing the transforms to plot
    names (list[string]): List of strings with one-to-one correspondence to list of poses
    tf_scale (float, optional): Length of transforms' axes
    tf_thickness (float, optional): Thickness of transforms' axes
    text_scale (float, optional): Font scale of transform name
    text_color_rgba (list, optional): desired RGBA values from 0.0 to 1.0 for the transform name
    duration (float, optional): Duration (seconds) to plot for
"""
function simPlotTransformsWithNames(c::AbstractVehicleClient, poses, names, tf_scale=5.0, tf_thickness=5.0, text_scale=10.0, text_color_rgba=[1.0, 0.0, 0.0, 1.0], duration=-1.0)
call(c, "simPlotTransformsWithNames", poses, names, tf_scale, tf_thickness, text_scale, text_color_rgba, duration)
end

"""
Cancel previous Async task

Args:
    vehicle_name (str, optional): Name of the vehicle
"""
function cancelLastTask(c::AbstractVehicleClient, vehicle_name::String="")
call(c, "cancelLastTask", vehicle_name)
end

#Recording APIsend

"""
Start Recording

Recording will be done according to the settings
"""
function startRecording(c::AbstractVehicleClient)
call(c, "startRecording")
end

"""
Stop Recording
"""
function stopRecording(c::AbstractVehicleClient)
call(c, "stopRecording")
end

"""
Whether Recording is running or not

Returns:
    bool: True if Recording, else false
"""
function isRecording(c::AbstractVehicleClient)
return call(c, "isRecording")
end

"""
Set simulated wind, in World frame, NED direction, m/s

Args:
    wind (Vector3r): Wind, in World frame, NED direction, in m/s
"""
function simSetWind(c::AbstractVehicleClient, wind)
call(c, "simSetWind", wind)
end

"""
Construct and save a binvox-formatted voxel grid of environment

Args:
    position (Vector3r): Position around which voxel grid is centered in m
    x, y, z (int): Size of each voxel grid dimension in m
    res (float): Resolution of voxel grid in m
    of (str): Name of output file to save voxel grid as

Returns:
    bool: True if output written to file successfully, else false
"""
function simCreateVoxelGrid(c::AbstractVehicleClient, position, x, y, z, res, of)
return call(c, "simCreateVoxelGrid", position, x, y, z, res, of)
end

#Add new vehicle via RPCend

"""
Create vehicle at runtime

Args:
    vehicle_name (str): Name of the vehicle being created
    vehicle_type (str): Type of vehicle, e.g. "simpleflight"
    pose (Pose): Initial pose of the vehicle
    pawn_path (str, optional): Vehicle blueprint path, default empty wbich uses the default blueprint for the vehicle type

Returns:
    bool: Whether vehicle was created
"""
function simAddVehicle(c::AbstractVehicleClient, vehicle_name, vehicle_type, pose, pawn_path="")
return call(c, "simAddVehicle", vehicle_name, vehicle_type, pose, pawn_path)
end

"""
Lists the names of current vehicles

Returns:
    list[str]: List containing names of all vehicles
"""
function listVehicles(c::AbstractVehicleClient)
return call(c, "listVehicles")
end

"""
Fetch the settings text being used by AirSim

Returns:
    str: Settings text in JSON format
"""
function getSettingsString(c::AbstractVehicleClient)
return call(c, "getSettingsString")
end

"""
Set arbitrary external forces, in World frame, NED direction. Can be used
for implementing simple payloads.

Args:
    ext_force (Vector3r): Force, in World frame, NED direction, in N
"""
function simSetExtForce(c::AbstractVehicleClient, ext_force)
call(c, "simSetExtForce", ext_force)
end

# -----------------------------------  Multirotor APIs ---------------------------------------------
abstract type AbstractMultirotorClient <: AbstractVehicleClient end

struct MultirotorClient <: AbstractMultirotorClient
end

# function MultirotorClient(c::AbstractMultirotorClient, ip="", port=41451, timeout_value=3600)
# super(MultirotorClient, self).__init__(ip, port, timeout_value)
# end

"""
Takeoff vehicle to 3m above ground. Vehicle should not be moving when this API is used

Args:
    timeout_sec (int, optional): Timeout for the vehicle to reach desired altitude
    vehicle_name (str, optional): Name of the vehicle to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function takeoffAsync(c::AbstractMultirotorClient, timeout_sec=20, vehicle_name::String="")
return call_async(c, "takeoff", timeout_sec, vehicle_name)
end

"""
Land the vehicle

Args:
    timeout_sec (int, optional): Timeout for the vehicle to land
    vehicle_name (str, optional): Name of the vehicle to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function landAsync(c::AbstractMultirotorClient, timeout_sec=60, vehicle_name::String="")
return call_async(c, "land", timeout_sec, vehicle_name)
end

"""
Return vehicle to Home i.e. Launch location

Args:
    timeout_sec (int, optional): Timeout for the vehicle to reach desired altitude
    vehicle_name (str, optional): Name of the vehicle to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function goHomeAsync(c::AbstractMultirotorClient, timeout_sec=3e+38, vehicle_name::String="")
return call_async(c, "goHome", timeout_sec, vehicle_name)
end
#APIs for controlend

"""
Args:
    vx (float): desired velocity in the X axis of the vehicle's local NED frame.
    vy (float): desired velocity in the Y axis of the vehicle's local NED frame.
    vz (float): desired velocity in the Z axis of the vehicle's local NED frame.
    duration (float): Desired amount of time (seconds), to send this command for
    drivetrain (DrivetrainType, optional):
    yaw_mode (YawMode, optional):
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByVelocityBodyFrameAsync(c::AbstractMultirotorClient, vx, vy, vz, duration, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(), vehicle_name::String="")
return call_async(c, "moveByVelocityBodyFrame", vx, vy, vz, duration, drivetrain, yaw_mode, vehicle_name)
end

"""
Args:
    vx (float): desired velocity in the X axis of the vehicle's local NED frame
    vy (float): desired velocity in the Y axis of the vehicle's local NED frame
    z (float): desired Z value (in local NED frame of the vehicle)
    duration (float): Desired amount of time (seconds), to send this command for
    drivetrain (DrivetrainType, optional):
    yaw_mode (YawMode, optional):
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByVelocityZBodyFrameAsync(c::AbstractMultirotorClient, vx, vy, z, duration, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(), vehicle_name::String="")

return call_async(c, "moveByVelocityZBodyFrame", vx, vy, z, duration, drivetrain, yaw_mode, vehicle_name)
end

function moveByAngleZAsync(c::AbstractMultirotorClient, pitch, roll, z, yaw, duration, vehicle_name::String="")
logging.warning("moveByAngleZAsync API is deprecated, use moveByRollPitchYawZAsync() API instead")
return call_async(c, "moveByRollPitchYawZ", roll, -pitch, -yaw, z, duration, vehicle_name)
end

function moveByAngleThrottleAsync(c::AbstractMultirotorClient, pitch, roll, throttle, yaw_rate, duration, vehicle_name::String="")
logging.warning("moveByAngleThrottleAsync API is deprecated, use moveByRollPitchYawrateThrottleAsync() API instead")
return call_async(c, "moveByRollPitchYawrateThrottle", roll, -pitch, -yaw_rate, throttle, duration, vehicle_name)
end

"""
Args:
    vx (float): desired velocity in world (NED) X axis
    vy (float): desired velocity in world (NED) Y axis
    vz (float): desired velocity in world (NED) Z axis
    duration (float): Desired amount of time (seconds), to send this command for
    drivetrain (DrivetrainType, optional):
    yaw_mode (YawMode, optional):
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByVelocityAsync(c::AbstractMultirotorClient, vx, vy, vz, duration, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(), vehicle_name::String="")
return call_async(c, "moveByVelocity", vx, vy, vz, duration, drivetrain, yaw_mode, vehicle_name)
end

function moveByVelocityZAsync(c::AbstractMultirotorClient, vx, vy, z, duration, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(), vehicle_name::String="")
return call_async(c, "moveByVelocityZ", vx, vy, z, duration, drivetrain, yaw_mode, vehicle_name)
end

function moveOnPathAsync(c::AbstractMultirotorClient, path, velocity, timeout_sec=3e+38, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(),
    lookahead=-1, adaptive_lookahead=1, vehicle_name="")
return call_async(c, "moveOnPath", path, velocity, timeout_sec, drivetrain, yaw_mode, lookahead, adaptive_lookahead, vehicle_name)
end

function moveToPositionAsync(c::AbstractMultirotorClient, x, y, z, velocity, timeout_sec=3e+38, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(),
    lookahead=-1, adaptive_lookahead=1, vehicle_name="")
return call_async(c, "moveToPosition", x, y, z, velocity, timeout_sec, drivetrain, yaw_mode, lookahead, adaptive_lookahead, vehicle_name)
end

function moveToGPSAsync(c::AbstractMultirotorClient, latitude, longitude, altitude, velocity, timeout_sec=3e+38, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(),
    lookahead=-1, adaptive_lookahead=1, vehicle_name="")
return call_async(c, "moveToGPS", latitude, longitude, altitude, velocity, timeout_sec, drivetrain, yaw_mode, lookahead, adaptive_lookahead, vehicle_name)
end

function moveToZAsync(c::AbstractMultirotorClient, z, velocity, timeout_sec=3e+38, yaw_mode=YawMode(), lookahead=-1, adaptive_lookahead=1, vehicle_name::String="")
return call_async(c, "moveToZ", z, velocity, timeout_sec, yaw_mode, lookahead, adaptive_lookahead, vehicle_name)
end

"""
- Read current RC state and use it to control the vehicles.

Parameters sets up the constraints on velocity and minimum altitude while flying. If RC state is detected to violate these constraints
then that RC state would be ignored.

Args:
    vx_max (float): max velocity allowed in x direction
    vy_max (float): max velocity allowed in y direction
    vz_max (float): max velocity allowed in z direction
    z_min (float): min z allowed for vehicle position
    duration (float): after this duration vehicle would switch back to non-manual mode
    drivetrain (DrivetrainType): when ForwardOnly, vehicle rotates itself so that its front is always facing the direction of travel. If MaxDegreeOfFreedom then it doesn't do that (crab-like movement)
    yaw_mode (YawMode): Specifies if vehicle should face at given angle (is_rate=false) or should be rotating around its axis at given rate (is_rate=True)
    vehicle_name (str, optional): Name of the multirotor to send this command to
Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByManualAsync(c::AbstractMultirotorClient, vx_max, vy_max, z_min, duration, drivetrain=DrivetrainType.MaxDegreeOfFreedom, yaw_mode=YawMode(), vehicle_name::String="")
return call_async(c, "moveByManual", vx_max, vy_max, z_min, duration, drivetrain, yaw_mode, vehicle_name)
end

function rotateToYawAsync(c::AbstractMultirotorClient, yaw, timeout_sec=3e+38, margin=5, vehicle_name::String="")
return call_async(c, "rotateToYaw", yaw, timeout_sec, margin, vehicle_name)
end

function rotateByYawRateAsync(c::AbstractMultirotorClient, yaw_rate, duration, vehicle_name::String="")
return call_async(c, "rotateByYawRate", yaw_rate, duration, vehicle_name)
end

function hoverAsync(c::AbstractMultirotorClient, vehicle_name::String="")
return call_async(c, "hover", vehicle_name)
end

function moveByRC(c::AbstractMultirotorClient, rcdata=RCData(), vehicle_name::String="")
return call(c, "moveByRC", rcdata, vehicle_name)
end
#low - level control APIend

"""
- Directly control the motors using PWM values

Args:
    front_right_pwm (float): PWM value for the front right motor (between 0.0 to 1.0)
    rear_left_pwm (float): PWM value for the rear left motor (between 0.0 to 1.0)
    front_left_pwm (float): PWM value for the front left motor (between 0.0 to 1.0)
    rear_right_pwm (float): PWM value for the rear right motor (between 0.0 to 1.0)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to
Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByMotorPWMsAsync(c::AbstractMultirotorClient, front_right_pwm, rear_left_pwm, front_left_pwm, rear_right_pwm, duration, vehicle_name::String="")
return call_async(c, "moveByMotorPWMs", front_right_pwm, rear_left_pwm, front_left_pwm, rear_right_pwm, duration, vehicle_name)
end

"""
- z is given in local NED frame of the vehicle.
- Roll angle, pitch angle, and yaw angle set points are given in **radians**, in the body frame.
- The body frame follows the Front Left Up (FLU) convention, and right-handedness.

- Frame Convention:
    - X axis is along the **Front** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **roll** angle.
    | Hence, rolling with a positive angle is equivalent to translating in the **right** direction, w.r.t. our FLU body frame.

    - Y axis is along the **Left** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **pitch** angle.
    | Hence, pitching with a positive angle is equivalent to translating in the **front** direction, w.r.t. our FLU body frame.

    - Z axis is along the **Up** direction.

    | Clockwise rotation about this axis defines a positive **yaw** angle.
    | Hence, yawing with a positive angle is equivalent to rotated towards the **left** direction wrt our FLU body frame. Or in an anticlockwise fashion in the body XY / FL plane.

Args:
    roll (float): Desired roll angle, in radians.
    pitch (float): Desired pitch angle, in radians.
    yaw (float): Desired yaw angle, in radians.
    z (float): Desired Z value (in local NED frame of the vehicle)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByRollPitchYawZAsync(c::AbstractMultirotorClient, roll, pitch, yaw, z, duration, vehicle_name::String="")
return call_async(c, "moveByRollPitchYawZ", roll, -pitch, -yaw, z, duration, vehicle_name)
end

"""
- Desired throttle is between 0.0 to 1.0
- Roll angle, pitch angle, and yaw angle are given in **degrees** when using PX4 and in **radians** when using SimpleFlight, in the body frame.
- The body frame follows the Front Left Up (FLU) convention, and right-handedness.

- Frame Convention:
    - X axis is along the **Front** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **roll** angle.
    | Hence, rolling with a positive angle is equivalent to translating in the **right** direction, w.r.t. our FLU body frame.

    - Y axis is along the **Left** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **pitch** angle.
    | Hence, pitching with a positive angle is equivalent to translating in the **front** direction, w.r.t. our FLU body frame.

    - Z axis is along the **Up** direction.

    | Clockwise rotation about this axis defines a positive **yaw** angle.
    | Hence, yawing with a positive angle is equivalent to rotated towards the **left** direction wrt our FLU body frame. Or in an anticlockwise fashion in the body XY / FL plane.

Args:
    roll (float): Desired roll angle.
    pitch (float): Desired pitch angle.
    yaw (float): Desired yaw angle.
    throttle (float): Desired throttle (between 0.0 to 1.0)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByRollPitchYawThrottleAsync(c::AbstractMultirotorClient, roll, pitch, yaw, throttle, duration, vehicle_name::String="")
return call_async(c, "moveByRollPitchYawThrottle", roll, -pitch, -yaw, throttle, duration, vehicle_name)
end

"""
- Desired throttle is between 0.0 to 1.0
- Roll angle, pitch angle, and yaw rate set points are given in **radians**, in the body frame.
- The body frame follows the Front Left Up (FLU) convention, and right-handedness.

- Frame Convention:
    - X axis is along the **Front** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **roll** angle.
    | Hence, rolling with a positive angle is equivalent to translating in the **right** direction, w.r.t. our FLU body frame.

    - Y axis is along the **Left** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **pitch** angle.
    | Hence, pitching with a positive angle is equivalent to translating in the **front** direction, w.r.t. our FLU body frame.

    - Z axis is along the **Up** direction.

    | Clockwise rotation about this axis defines a positive **yaw** angle.
    | Hence, yawing with a positive angle is equivalent to rotated towards the **left** direction wrt our FLU body frame. Or in an anticlockwise fashion in the body XY / FL plane.

Args:
    roll (float): Desired roll angle, in radians.
    pitch (float): Desired pitch angle, in radians.
    yaw_rate (float): Desired yaw rate, in radian per second.
    throttle (float): Desired throttle (between 0.0 to 1.0)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByRollPitchYawrateThrottleAsync(c::AbstractMultirotorClient, roll, pitch, yaw_rate, throttle, duration, vehicle_name::String="")
return call_async(c, "moveByRollPitchYawrateThrottle", roll, -pitch, -yaw_rate, throttle, duration, vehicle_name)
end

"""
- z is given in local NED frame of the vehicle.
- Roll angle, pitch angle, and yaw rate set points are given in **radians**, in the body frame.
- The body frame follows the Front Left Up (FLU) convention, and right-handedness.

- Frame Convention:
    - X axis is along the **Front** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **roll** angle.
    | Hence, rolling with a positive angle is equivalent to translating in the **right** direction, w.r.t. our FLU body frame.

    - Y axis is along the **Left** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **pitch** angle.
    | Hence, pitching with a positive angle is equivalent to translating in the **front** direction, w.r.t. our FLU body frame.

    - Z axis is along the **Up** direction.

    | Clockwise rotation about this axis defines a positive **yaw** angle.
    | Hence, yawing with a positive angle is equivalent to rotated towards the **left** direction wrt our FLU body frame. Or in an anticlockwise fashion in the body XY / FL plane.

Args:
    roll (float): Desired roll angle, in radians.
    pitch (float): Desired pitch angle, in radians.
    yaw_rate (float): Desired yaw rate, in radian per second.
    z (float): Desired Z value (in local NED frame of the vehicle)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByRollPitchYawrateZAsync(c::AbstractMultirotorClient, roll, pitch, yaw_rate, z, duration, vehicle_name::String="")
return call_async(c, "moveByRollPitchYawrateZ", roll, -pitch, -yaw_rate, z, duration, vehicle_name)
end

"""
- z is given in local NED frame of the vehicle.
- Roll rate, pitch rate, and yaw rate set points are given in **radians**, in the body frame.
- The body frame follows the Front Left Up (FLU) convention, and right-handedness.

- Frame Convention:
    - X axis is along the **Front** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **roll** angle.
    | Hence, rolling with a positive angle is equivalent to translating in the **right** direction, w.r.t. our FLU body frame.

    - Y axis is along the **Left** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **pitch** angle.
    | Hence, pitching with a positive angle is equivalent to translating in the **front** direction, w.r.t. our FLU body frame.

    - Z axis is along the **Up** direction.

    | Clockwise rotation about this axis defines a positive **yaw** angle.
    | Hence, yawing with a positive angle is equivalent to rotated towards the **left** direction wrt our FLU body frame. Or in an anticlockwise fashion in the body XY / FL plane.

Args:
    roll_rate (float): Desired roll rate, in radians / second
    pitch_rate (float): Desired pitch rate, in radians / second
    yaw_rate (float): Desired yaw rate, in radians / second
    z (float): Desired Z value (in local NED frame of the vehicle)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByAngleRatesZAsync(c::AbstractMultirotorClient, roll_rate, pitch_rate, yaw_rate, z, duration, vehicle_name::String="")
return call_async(c, "moveByAngleRatesZ", roll_rate, -pitch_rate, -yaw_rate, z, duration, vehicle_name)
end

"""
- Desired throttle is between 0.0 to 1.0
- Roll rate, pitch rate, and yaw rate set points are given in **radians**, in the body frame.
- The body frame follows the Front Left Up (FLU) convention, and right-handedness.

- Frame Convention:
    - X axis is along the **Front** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **roll** angle.
    | Hence, rolling with a positive angle is equivalent to translating in the **right** direction, w.r.t. our FLU body frame.

    - Y axis is along the **Left** direction of the quadrotor.

    | Clockwise rotation about this axis defines a positive **pitch** angle.
    | Hence, pitching with a positive angle is equivalent to translating in the **front** direction, w.r.t. our FLU body frame.

    - Z axis is along the **Up** direction.

    | Clockwise rotation about this axis defines a positive **yaw** angle.
    | Hence, yawing with a positive angle is equivalent to rotated towards the **left** direction wrt our FLU body frame. Or in an anticlockwise fashion in the body XY / FL plane.

Args:
    roll_rate (float): Desired roll rate, in radians / second
    pitch_rate (float): Desired pitch rate, in radians / second
    yaw_rate (float): Desired yaw rate, in radians / second
    throttle (float): Desired throttle (between 0.0 to 1.0)
    duration (float): Desired amount of time (seconds), to send this command for
    vehicle_name (str, optional): Name of the multirotor to send this command to

Returns:
    msgpackrpc.future.Future: future. call .join() to wait for method to finish. Example: client.METHOD().join()
"""
function moveByAngleRatesThrottleAsync(c::AbstractMultirotorClient, roll_rate, pitch_rate, yaw_rate, throttle, duration, vehicle_name::String="")
return call_async(c, "moveByAngleRatesThrottle", roll_rate, -pitch_rate, -yaw_rate, throttle, duration, vehicle_name)
end

"""
- Modifying these gains will have an affect on *ALL* move*() APIs.
    This is because any velocity setpoint is converted to an angle level setpoint which is tracked with an angle level controllers.
    That angle level setpoint is itself tracked with and angle rate controller.
- This function should only be called if the default angle rate control PID gains need to be modified.

Args:
    angle_rate_gains (AngleRateControllerGains):
        - Correspond to the roll, pitch, yaw axes, defined in the body frame.
        - Pass AngleRateControllerGains() to reset gains to default recommended values.
    vehicle_name (str, optional): Name of the multirotor to send this command to
"""
function setAngleRateControllerGains(c::AbstractMultirotorClient, angle_rate_gains=AngleRateControllerGains(), vehicle_name::String="")
call(c, "setAngleRateControllerGains", *(angle_rate_gains.to_lists()+(vehicle_name,)))
end

"""
- Sets angle level controller gains (used by any API setting angle references - for ex: moveByRollPitchYawZAsync(), moveByRollPitchYawThrottleAsync(), etc)
- Modifying these gains will also affect the behaviour of moveByVelocityAsync() API.
    This is because the AirSim flight controller will track velocity setpoints by converting them to angle set points.
- This function should only be called if the default angle level control PID gains need to be modified.
- Passing AngleLevelControllerGains() sets gains to default airsim values.

Args:
    angle_level_gains (AngleLevelControllerGains):
        - Correspond to the roll, pitch, yaw axes, defined in the body frame.
        - Pass AngleLevelControllerGains() to reset gains to default recommended values.
    vehicle_name (str, optional): Name of the multirotor to send this command to
"""
function setAngleLevelControllerGains(c::AbstractMultirotorClient, angle_level_gains=AngleLevelControllerGains(), vehicle_name::String="")
call(c, "setAngleLevelControllerGains", *(angle_level_gains.to_lists()+(vehicle_name,)))
end

"""
- Sets velocity controller gains for moveByVelocityAsync().
- This function should only be called if the default velocity control PID gains need to be modified.
- Passing VelocityControllerGains() sets gains to default airsim values.

Args:
    velocity_gains (VelocityControllerGains):
        - Correspond to the world X, Y, Z axes.
        - Pass VelocityControllerGains() to reset gains to default recommended values.
        - Modifying velocity controller gains will have an affect on the behaviour of moveOnSplineAsync() and moveOnSplineVelConstraintsAsync(), as they both use velocity control to track the trajectory.
    vehicle_name (str, optional): Name of the multirotor to send this command to
"""
function setVelocityControllerGains(c::AbstractMultirotorClient, velocity_gains=VelocityControllerGains(), vehicle_name::String="")
call(c, "setVelocityControllerGains", *(velocity_gains.to_lists()+(vehicle_name,)))

end

"""
Sets position controller gains for moveByPositionAsync.
This function should only be called if the default position control PID gains need to be modified.

Args:
    position_gains (PositionControllerGains):
        - Correspond to the X, Y, Z axes.
        - Pass PositionControllerGains() to reset gains to default recommended values.
    vehicle_name (str, optional): Name of the multirotor to send this command to
"""
function setPositionControllerGains(c::AbstractMultirotorClient, position_gains=PositionControllerGains(), vehicle_name::String="")
call(c, "setPositionControllerGains", *(position_gains.to_lists()+(vehicle_name,)))
end
#query vehicle stateend

"""
The position inside the returned MultirotorState is in the frame of the vehicle's starting point

Args:
    vehicle_name (str, optional): Vehicle to get the state of

Returns:
    MultirotorState:
"""
function getMultirotorState(c::AbstractMultirotorClient, vehicle_name::String="")
return MultirotorState.from_msgpack(call(c, "getMultirotorState", vehicle_name))
end
#query rotor statesend

"""
Used to obtain the current state of all a multirotor's rotors. The state includes the speeds,
thrusts and torques for all rotors.

Args:
    vehicle_name (str, optional): Vehicle to get the rotor state of

Returns:
    RotorStates: Containing a timestamp and the speed, thrust and torque of all rotors.
"""
function getRotorStates(c::AbstractMultirotorClient, vehicle_name::String="")
return RotorStates.from_msgpack(call(c, "getRotorStates", vehicle_name))
end

#----------------------------------- Car APIs ---------------------------------------------
abstract type AbstractCarClient <: AbstractVehicleClient
end

struct CarClient <: AbstractVehicleClient end

# function CarClient(c::AbstractCarClient, ip="", port=41451, timeout_value=3600)
#     CarClient()
# end

"""
Control the car using throttle, steering, brake, etc.

Args:
    controls (CarControls): Struct containing control values
    vehicle_name (str, optional): Name of vehicle to be controlled
"""
function setCarControls(c::AbstractCarClient, controls, vehicle_name::String="")
call(c, "setCarControls", controls, vehicle_name)
end

"""
The position inside the returned CarState is in the frame of the vehicle's starting point

Args:
    vehicle_name (str, optional): Name of vehicle

Returns:
    CarState:
"""
function getCarState(c::AbstractCarClient, vehicle_name::String="")
state_raw = call(c, "getCarState", vehicle_name)
return CarState.from_msgpack(state_raw)
end

"""
Args:
    vehicle_name (str, optional): Name of vehicle

Returns:
    CarControls:
"""
function getCarControls(c::AbstractCarClient, vehicle_name::String="")
controls_raw = call(c, "getCarControls", vehicle_name)
return CarControls.from_msgpack(controls_raw)
end
