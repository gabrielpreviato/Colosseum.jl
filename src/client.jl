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

"""
        reset(c::VehicleClient)
    
    Reset the vehicle to its original starting state

    Note that you must call `enableApiControl` and `armDisarm` again after the call to reset
    """
function reset(c::VehicleClient)::Nothing
    
    call(c, "reset")
end

"""
        ping(c::VehicleClient)

    If connection is established then this call will return true otherwise it will be blocked until timeout
    """
function ping(c::VehicleClient)::Bool
    
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

"""
    Enables || disables API control for vehicle corresponding to vehicle_name

    Args:
        is_enabled (bool) True to enable, false to disable API control
        vehicle_name (str, optional) Name of the vehicle to send this command to
        """
function getMinRequiredClientVersion(c::VehicleClient)
    
    return call(c, "getMinRequiredClientVersion")
end

# Basic flight control
function enableApiControl(c::VehicleClient, is_enabled::Bool, vehicle_name::String="")
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
function isApiControlEnabled(c::VehicleClient, vehicle_name::String="")
    
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
function armDisarm(c::VehicleClient, arm::Bool, vehicle_name::String="")
    
    return call(c, "armDisarm", arm, vehicle_name)
end

"""
    Pauses simulation

    Args:
        is_paused (bool) True to pause the simulation, false to release
    """
function simPause(c::VehicleClient, is_paused::Bool)
    
    call(c, "simPause", is_paused)
end

"""
    Returns true if the simulation is paused

    Returns:
        bool: If the simulation is paused
    """
function simIsPause(c::VehicleClient)
    
    return call(c, "simIsPaused")
end

"""
    Continue the simulation for the specified number of seconds

    Args:
        seconds (float) Time to run the simulation for
    """
function simContinueForTime(c::VehicleClient, seconds::Real)
    
    call(c, "simContinueForTime", seconds)
end

"""
    Continue (or resume if paused) the simulation for the specified number of frames, after which the simulation will be paused.

    Args:
        frames (int) Frames to run the simulation for
    """
function simContinueForFrames(c::VehicleClient, frames)
    
    call(c, "simContinueForFrames", frames)
end

"""
    Get the Home location of the vehicle

    Args:
        vehicle_name (str, optional) Name of vehicle to get home location of

    Returns:
        GeoPoint: Home location of the vehicle
    """
function getHomeGeoPoint(c::VehicleClient, vehicle_name="")
    
    msg = call(c, "getHomeGeoPoint", vehicle_name)
    return MsgPack.from_msgpack(GeoPoint, msg)
end


"""
    Checks state of connection every 1 sec and reports it in Console so user can see the progress for connection.
    """
function confirmConnection(c::VehicleClient)
    
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
function simSetLightIntensity(c::VehicleClient, light_name::String, intensity::Real)
    
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
function simSwapTextures(c::VehicleClient, tags, tex_id=0, component_id=0, material_id=0)
    
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
function simSetObjectMaterial(c::VehicleClient, object_name, material_name, component_id=0)
    
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
function simSetObjectMaterialFromTexture(c::VehicleClient, object_name, texture_path, component_id=0)
    
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
function simSetTimeOfDay(c::VehicleClient, is_enabled::Bool, start_datetime::String="", is_start_datetime_dst::Bool=false, celestial_clock_speed::Int=1, update_interval_secs::Int=60, move_sun::Bool=true)
    
    call(c, "simSetTimeOfDay", is_enabled, start_datetime, is_start_datetime_dst, celestial_clock_speed, update_interval_secs, move_sun)
end

#weather
"""
    Enable Weather effects. Needs to be called before using `simSetWeatherParameter` API

    Args:
        enable (bool) True to enable, false to disable
    """
function simEnableWeather(c::VehicleClient, enable::Bool)
    
    call(c, "simEnableWeather", enable)
end

"""
    Enable various weather effects

    Args:
        param (WeatherParameter) Weather effect to be enabled
        val (float) Intensity of the effect, Range 0-1
    """
function simSetWeatherParameter(c::VehicleClient, param, val::Real)
    
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
function simGetImage(c::VehicleClient, camera_name::Union{String,Int}, image_type::ImageType, vehicle_name::String="", external::Bool=false)
    

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
function simGetImages(c::VehicleClient, requests::Vector{ImageRequest}, vehicle_name::String="", external::Bool=false)
    
    responses_raw = call(c, "simGetImages", requests, vehicle_name, external)
    return [response_raw for response_raw in responses_raw]
end


#CinemAirSim
function simGetPresetLensSettings(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    result = call(c, "simGetPresetLensSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
    return result

end

function simGetLensSettings(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    result = call(c, "simGetLensSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
return result
end

function simSetPresetLensSettings(c::VehicleClient, preset_lens_settings, camera_name, vehicle_name="", external=false)  
    call(c, "simSetPresetLensSettings", preset_lens_settings, camera_name, vehicle_name, external)
end

function simGetPresetFilmbackSettings(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    result = call(c, "simGetPresetFilmbackSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
    return result

end

function simSetPresetFilmbackSettings(c::VehicleClient, preset_filmback_settings, camera_name, vehicle_name="", external=false)  
    call(c, "simSetPresetFilmbackSettings", preset_filmback_settings, camera_name, vehicle_name, external)
end

function simGetFilmbackSettings(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    result = call(c, "simGetFilmbackSettings", camera_name, vehicle_name, external)
    if (result == "" || result == "\0")
        return nothing
    end
    return result
end

function simSetFilmbackSettings(c::VehicleClient, sensor_width, sensor_height, camera_name, vehicle_name="", external=false)  
    return call(c, "simSetFilmbackSettings", sensor_width, sensor_height, camera_name, vehicle_name, external)
end

function simGetFocalLength(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    return call(c, "simGetFocalLength", camera_name, vehicle_name, external)
end

function simSetFocalLength(c::VehicleClient, focal_length, camera_name, vehicle_name="", external=false)  
    call(c, "simSetFocalLength", focal_length, camera_name, vehicle_name, external)
end

function simEnableManualFocus(c::VehicleClient, enable, camera_name, vehicle_name="", external=false)  
    call(c, "simEnableManualFocus", enable, camera_name, vehicle_name, external)
end

function simGetFocusDistance(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    return call(c, "simGetFocusDistance", camera_name, vehicle_name, external)
end

function simSetFocusDistance(c::VehicleClient, focus_distance, camera_name, vehicle_name="", external=false)  
    call(c, "simSetFocusDistance", focus_distance, camera_name, vehicle_name, external)
end

function simGetFocusAperture(c::VehicleClient, camera_name, vehicle_name="", external=false)  
    return call(c, "simGetFocusAperture", camera_name, vehicle_name, external)
end

function simSetFocusAperture(c::VehicleClient, focus_aperture, camera_name, vehicle_name="", external=false)  
    call(c, "simSetFocusAperture", focus_aperture, camera_name, vehicle_name, external)
end

function simEnableFocusPlane(c::VehicleClient, enable, camera_name, vehicle_name="", external=false)  
    call(c, "simEnableFocusPlane", enable, camera_name, vehicle_name, external)
end

function simGetCurrentFieldOfView(c::VehicleClient, camera_name, vehicle_name="", external=false)  
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
function simTestLineOfSightToPoint(c::VehicleClient, point, vehicle_name="")
    
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
function simTestLineOfSightBetweenPoints(c::VehicleClient, point1, point2)
    
    return call(c, "simTestLineOfSightBetweenPoints", point1, point2)
end

"""
    Returns a list of GeoPoints representing the minimum and maximum extents of the world

    Returns:
        list[GeoPoint]
    """
function simGetWorldExtents(c::VehicleClient)
    
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
function simRunConsoleCommand(c::VehicleClient, command)
    
    return call(c, "simRunConsoleCommand", command)
end

#gets the static meshes in the unreal scene
"""
    Returns the static meshes that make up the scene

    See https://microsoft.github.io/AirSim/meshes/ for details and how to use this

    Returns:
        list[MeshPositionVertexBuffersResponse]:
    """
function simGetMeshPositionVertexBuffers(c::VehicleClient)
    
    responses_raw = call(c, "simGetMeshPositionVertexBuffers")
    return [MeshPositionVertexBuffersResponse.from_msgpack(response_raw) for response_raw in responses_raw]
end

"""
    Args:
        vehicle_name (str, optional) Name of the Vehicle to get the info of

    Returns:
        CollisionInfo:
    """
function simGetCollisionInfo(c::VehicleClient, vehicle_name="")
    
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
function simSetVehiclePose(c::VehicleClient, pose, ignore_collision, vehicle_name="")
    
    call(c, "simSetVehiclePose", pose, ignore_collision, vehicle_name)
end

"""
    The position inside the returned Pose is in the frame of the vehicle's starting point

    Args:
        vehicle_name (str, optional) Name of the vehicle to get the Pose of

    Returns:
        Pose:
    """
function simGetVehiclePose(c::VehicleClient, vehicle_name="")
    
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
function simSetTraceLine(c::VehicleClient, color_rgba, thickness=1.0, vehicle_name="")
    
    call(c, "simSetTraceLine", color_rgba, thickness, vehicle_name)

end

"""
    The position inside the returned Pose is in the world frame

    Args:
        object_name (str) Object to get the Pose of

    Returns:
        Pose:
    """
function simGetObjectPose(c::VehicleClient, object_name)
    
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
function simSetObjectPose(c::VehicleClient, object_name, pose, teleport=True)
    
    return call(c, "simSetObjectPose", object_name, pose, teleport)

end

"""
    Gets scale of an object in the world

    Args:
        object_name (str) Object to get the scale of

    Returns:
        airsim.Vector3r: Scale
    """
function simGetObjectScale(c::VehicleClient, object_name)
    
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
function simSetObjectScale(c::VehicleClient, object_name, scale_vector)
    
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
function simListSceneObjects(c::VehicleClient, name_regex=".*")
    
    return call(c, "simListSceneObjects", name_regex)

end

"""
    Loads a level specified by its name

    Args:
        level_name (str) Name of the level to load

    Returns:
        bool: True if the level was successfully loaded
    """
function simLoadLevel(c::VehicleClient, level_name)
    
    return call(c, "simLoadLevel", level_name)

end

"""
    Lists all the assets present in the Asset Registry

    Returns:
        list[str]: Names of all the assets
    """
function simListAssets(c::VehicleClient)
    
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
function simSpawnObject(c::VehicleClient, object_name, asset_name, pose, scale, physics_enabled=false, is_blueprint=false)
    
    return call(c, "simSpawnObject", object_name, asset_name, pose, scale, physics_enabled, is_blueprint)

end

"""Removes selected object from the world

    Args:
        object_name (str) Name of object to be removed

    Returns:
        bool: True if object is queued up for removal
    """
function simDestroyObject(c::VehicleClient, object_name)
    
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
function simSetSegmentationObjectID(c::VehicleClient, mesh_name, object_id, is_name_regex=false)
    
    return call(c, "simSetSegmentationObjectID", mesh_name, object_id, is_name_regex)

end

"""
    Returns Object ID for the given mesh name

    Mapping of Object IDs to RGB values can be seen at https://microsoft.github.io/AirSim/seg_rgbs.txt

    Args:
        mesh_name (str) Name of the mesh to get the ID of
    """
function simGetSegmentationObjectID(c::VehicleClient, mesh_name)
    
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
function simAddDetectionFilterMeshName(c::VehicleClient, camera_name, image_type, mesh_name, vehicle_name="", external=false)
    
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
function simSetDetectionFilterRadius(c::VehicleClient, camera_name, image_type, radius_cm, vehicle_name="", external=false)
    
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
function simClearDetectionMeshNames(c::VehicleClient, camera_name, image_type, vehicle_name="", external=false)
    
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
function simGetDetections(c::VehicleClient, camera_name, image_type, vehicle_name="", external=false)
    
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
function simPrintLogMessage(c::VehicleClient, message, message_param="", severity=0)
    
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
function simGetCameraInfo(c::VehicleClient, camera_name, vehicle_name="", external=false)
    
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
function simGetDistortionParams(c::VehicleClient, camera_name, vehicle_name="", external=false)
    

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
function simSetDistortionParams(c::VehicleClient, camera_name, distortion_params, vehicle_name="", external=false)
    

    for (param_name, value) in items(distortion_params)
        c::VehicleClient.simSetDistortionParam(camera_name, param_name, value, vehicle_name, external)
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
function simSetDistortionParam(c::VehicleClient, camera_name, param_name, value, vehicle_name="", external=false)
    
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
function simSetCameraPose(c::VehicleClient, camera_name, pose, vehicle_name="", external=false)
    
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
function simSetCameraFov(c::VehicleClient, camera_name, fov_degrees, vehicle_name="", external=false)
    
#TODO : below str() conversion is only needed for legacy reason and should be removed in future
    call(c, "simSetCameraFov", str(camera_name), fov_degrees, vehicle_name, external)
end
