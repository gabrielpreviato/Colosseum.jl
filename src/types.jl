
using MsgPack
using LinearAlgebra

@enum ImageType Scene=0 DepthPlanar=1 DepthPerspective=2 DepthVis=3 DisparityNormalized=4 Segmentation=5 SurfaceNormals=6 Infrared=7 OpticalFlow=8 OpticalFlowVis=9

MsgPack.msgpack_type(::Type{ImageType}) = MsgPack.IntegerType()

Base.isless(a::Colosseum.ImageType, b::Int) = Base.isless(Int(a), b)

@enum DrivetrainType MaxDegreeOfFreedom=0 ForwardOnly=1

@enum LandedState Landed=0 Flying=1

@enum WeatherParameter Rain=0 Roadwetness=1 Snow=2 RoadSnow=3 MapleLeaf=4 RoadLeaf=5 Dust=6 Fog=7 Enabled=8

struct ImageRequest
    camera_name::String
    image_type::ImageType
    pixel_as_float::Bool
    compress::Bool
end

MsgPack.msgpack_type(::Type{ImageRequest}) = MsgPack.StructType()

struct Vector2r
    x_val::Real
    y_val::Real
end

MsgPack.msgpack_type(::Type{Vector2r}) = MsgPack.StructType()

function Vector2r()
    Vector2r(0.0, 0.0)
end

struct Vector3r
    x_val::Real
    y_val::Real
    z_val::Real
end

MsgPack.msgpack_type(::Type{Vector3r}) = MsgPack.StructType()

Vector3r() = Vector3r(0.0, 0.0, 0.0)
Vector3r(d::Dict{Any, Any}) = Vector3r(d["x_val"], d["y_val"], d["z_val"])

function nanVector3r()
    Vector3r(NaN, NaN, NaN)
end

function containsNan(v::Vector3r)
    v.x_val == NaN || v.y_val == NaN || v.z_val == NaN
end

function Base.:+(v::Vector3r, other::Vector3r)
    Vector3r(v.x_val + other.x_val, v.y_val + other.y_val, v.z_val + other.z_val)
end

function Base.:-(v::Vector3r, other::Vector3r)
    Vector3r(v.x_val - other.x_val, v.y_val - other.y_val, v.z_val - other.z_val)
end

function Base.:/(v::Vector3r, other::Real)
    Vector3r(v.x_val / other, v.y_val / other, v.z_val / other)
end

function Base.:*(v::Vector3r, other::Real)
    Vector3r(v.x_val * other, v.y_val * other, v.z_val * other)
end

function dot(v::Vector3r, other::Vector3r)
    v.x_val*other.x_val + v.y_val*other.y_val + v.z_val*other.z_val
end

function cross(v::Vector3r, other::Vector3r)
    cross_product = cross([v.x_val; v.y_val; v.z_val], [other.x_val; other.y_val; other.z_val])
    return Vector3r(cross_product[1], cross_product[2], cross_product[3])
end

function get_length(v::Vector3r)
    sqrt(v.x_val^2 + v.y_val^2 + v.z_val^2 )
end

function distance_to(v::Vector3r, other::Vector3r)
    return sqrt((v.x_val-other.x_val)^2 + (v.y_val-other.y_val)^2 + (v.z_val-other.z_val)^2)
end

function to_Quaternionr(v::Vector3r)
    return Quaternionr(v.x_val, v.y_val, v.z_val, 0.0)
end

struct Quaternionr
    x_val::Real
    y_val::Real
    z_val::Real
    w_val::Real
end

MsgPack.msgpack_type(::Type{Quaternionr}) = MsgPack.StructType()

Quaternionr() = Quaternionr(0.0, 0.0, 0.0, 0.0)
Quaternionr(d::Dict{Any, Any}) = Quaternionr(d["x_val"], d["y_val"], d["z_val"], d["w_val"])

function nanQuaternionr()
    Quaternionr(NaN, NaN, NaN, NaN)
end

function containsNan(q::Quaternionr)
    q.x_val == NaN || q.y_val == NaN || q.z_val == NaN || q.w_val == NaN
end

function Base.:+(q::Quaternionr, other::Quaternionr)
    Quaternionr(q.x_val+other.x_val, q.y_val+other.y_val, q.z_val+other.z_val, q.w_val+other.w_val)
end

function Base.:-(q::Quaternionr, other::Quaternionr)
    Quaternionr(q.x_val-other.x_val, q.y_val-other.y_val, q.z_val-other.z_val, q.w_val-other.w_val)
end

function Base.:*(q::Quaternionr, other::Quaternionr)
    t, x, y, z = q.w_val, q.x_val, q.y_val, q.z_val
    a, b, c, d = other.w_val, other.x_val, other.y_val, other.z_val
    return Quaternionr(a*t - b*x - c*y - d*z,
                       b*t + a*x + d*y - c*z,
                       c*t + a*y + b*z - d*x,
                       d*t + z*a + c*x - b*y)
end

function Base.:/(q::Quaternionr, other::Quaternionr)
    q * inverse(other)
end

function Base.:/(q::Quaternionr, other::Real)
    Quaternionr(q.x_val / other, q.y_val / other, q.z_val / other, q.w_val / other)
end

function dot(q::Quaternionr, other::Quaternionr)
    q.x_val*other.x_val + q.y_val*other.y_val + q.z_val*other.z_val + q.w_val*other.w_val
end

function cross(q::Quaternionr, other::Quaternionr)
    (q * other - other * q) / 2
end

function outer_product(q::Quaternionr, other::Quaternionr)
    return ( q.inverse()*other - other.inverse()*q ) / 2
end

function rotate(q::Quaternionr, other::Quaternionr)
    if get_length(other) == 1
        return other * q * inverse(other)
    else
        throw("length of the other Quaternionr must be 1")
    end
end

function conjugate(q::Quaternionr)
    Quaternionr(-q.x_val, -q.y_val, -q.z_val, q.w_val)
end

function star(q::Quaternionr)
    conjugate(q)
end

function inverse(q::Quaternionr)
    star(q) / dot(q, q)
end

function sgn(q::Quaternionr)
    q / get_length(q)
end

function get_length(q::Quaternionr)
    sqrt(q.x_val^2 + q.y_val^2 + q.z_val^2 + q.w_val^2)
end

struct Pose
    position::Vector3r
    orientation::Quaternionr
end

MsgPack.msgpack_type(::Type{Pose}) = MsgPack.StructType()

Pose() = Pose(Vector3r(), Quaternionr())
Pose(d::Dict{Any, Any}) = Pose(Vector3r(d["position"]), Quaternionr(d["orientation"]))

function nanPose()
    Pose(nanVector3r(), nanQuaternionr())
end

function containsNan(p::Pose)
    containsNan(p.position) || containsNan(p.orientation)
end

struct CollisionInfo
    has_collided::Bool
    normal::Vector3r
    impact_point::Vector3r
    position::Vector3r
    penetration_depth::Real
    time_stamp::Real
    object_name::String
    object_id::Int
end

MsgPack.msgpack_type(::Type{CollisionInfo}) = MsgPack.StructType()

function CollisionInfo()
    CollisionInfo(false, Vector3r(), Vector3r(), Vector3r(), 0.0, 0.0, "", -1)
end

struct GeoPoint
    latitude::Real 
    longitude::Real
    altitude::Real
end

GeoPoint() = GeoPoint(0.0, 0.0, 0.0)
# GeoPoint(msg::Dict{Any, Any}) = GeoPoint(msg["latitude"], msg["longitude"], msg["altitude"])

MsgPack.msgpack_type(::Type{GeoPoint}) = MsgPack.StructType()
# MsgPack.from_msgpack(::Type{GeoPoint}, x::Dict{Any, Any}) = GeoPoint(x)

struct YawMode
    is_rate::Bool
    yaw_or_rate::Real
end

MsgPack.msgpack_type(::Type{YawMode}) = MsgPack.StructType()

YawMode() = YawMode(true, 0.0)

struct RCData
    timestamp::Int
    pitch::Real
    roll::Real
    throttle::Real
    yaw::Real
    switch1::Int
    switch2::Int
    switch3::Int
    switch4::Int
    switch5::Int
    switch6::Int
    switch7::Int
    switch8::Int
    is_initialized::Bool
    is_valid::Bool
end

MsgPack.msgpack_type(::Type{RCData}) = MsgPack.StructType()

RCData() = RCData(0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, false, false)

struct ImageResponse
    image_data_uint8::Vector{UInt8}
    image_data_float::Vector{Float32}
    camera_position::Vector3r
    camera_orientation::Quaternionr
    time_stamp::Int
    message::String
    pixels_as_float::Bool
    compress::Bool
    width::Int
    height::Int
    image_type::ImageType
end

MsgPack.msgpack_type(::Type{ImageResponse}) = MsgPack.StructType()
# MsgPack.from_msgpack(::Type{ImageResponse}, x::Dict{Any, Any}) = ImageResponse(x)

ImageResponse() = ImageResponse(Vector{UInt8}(undef, 0x00), Vector{Float32}(undef, 0.0f0), Vector3r(), Quaternionr(), 0, "", false, true, 0, 0, Scene)

# struct CarControls
#         throttle = 0.0
#         steering = 0.0
#         brake = 0.0
#         handbrake = False
#         is_manual_gear = False
#         manual_gear = 0
#         gear_immediate = True
    
    
#         function set_throttle(self, throttle_val, forward)
#             if (forward)
#                 self.is_manual_gear = False
#                 self.manual_gear = 0
#                 self.throttle = abs(throttle_val)
#             else
#                 self.is_manual_gear = False
#                 self.manual_gear = -1
#                 self.throttle = - abs(throttle_val)
#             end
#         end
    
#     end

# struct KinematicsState
#         position = Vector3r()
#         orientation = Quaternionr()
#         linear_velocity = Vector3r()
#         angular_velocity = Vector3r()
#         linear_acceleration = Vector3r()
#         angular_acceleration = Vector3r()
    
#     end

# struct EnvironmentState
#         position = Vector3r()
#         geo_point = GeoPoint()
#         gravity = Vector3r()
#         air_pressure = 0.0
#         temperature = 0.0
#         air_density = 0.0
    
#     end

# struct CarState
#         speed = 0.0
#         gear = 0
#         rpm = 0.0
#         maxrpm = 0.0
#         handbrake = False
#         collision = CollisionInfo()
#         kinematics_estimated = KinematicsState()
#         timestamp = np.uint64(0)
    
#     end

# struct MultirotorState
#         collision = CollisionInfo()
#         kinematics_estimated = KinematicsState()
#         gps_location = GeoPoint()
#         timestamp = np.uint64(0)
#         landed_state = LandedState.Landed
#         rc_data = RCData()
#         ready = False
#         ready_message = ""
#         can_arm = False
    
#     end

# struct RotorStates
#         timestamp = np.uint64(0)
#         rotors = []
    
#     end

# struct ProjectionMatrix
#         matrix = []
    
#     end

# struct CameraInfo
#         pose = Pose()
#         fov = -1
#         proj_mat = ProjectionMatrix()
    
#     end

# struct LidarData
#         point_cloud = 0.0
#         time_stamp = np.uint64(0)
#         pose = Pose()
#         segmentation = 0
    
#     end

# struct ImuData
#         time_stamp = np.uint64(0)
#         orientation = Quaternionr()
#         angular_velocity = Vector3r()
#         linear_acceleration = Vector3r()
    
#     end

# struct BarometerData
#         time_stamp = np.uint64(0)
#         altitude = Quaternionr()
#         pressure = Vector3r()
#         qnh = Vector3r()
    
#     end

# struct MagnetometerData
#         time_stamp = np.uint64(0)
#         magnetic_field_body = Vector3r()
#         magnetic_field_covariance = 0.0
    
#     end

# struct GnssFixType
#         GNSS_FIX_NO_FIX = 0
#         GNSS_FIX_TIME_ONLY = 1
#         GNSS_FIX_2D_FIX = 2
#         GNSS_FIX_3D_FIX = 3
    
#     end

# struct GnssReport
#         geo_point = GeoPoint()
#         eph = 0.0
#         epv = 0.0
#         velocity = Vector3r()
#         fix_type = GnssFixType()
#         time_utc = np.uint64(0)
    
#     end

# struct GpsData
#         time_stamp = np.uint64(0)
#         gnss = GnssReport()
#         is_valid = False
    
#     end

# struct DistanceSensorData
#         time_stamp = np.uint64(0)
#         distance = 0.0
#         min_distance = 0.0
#         max_distance = 0.0
#         relative_pose = Pose()
    
#     end

# struct Box2D
#         min = Vector2r()
#         max = Vector2r()
    
#     end

# struct Box3D
#         min = Vector3r()
#         max = Vector3r()
    
#     end

# struct DetectionInfo
#         name = ''
#         geo_point = GeoPoint()
#         box2D = Box2D()
#         box3D = Box3D()
#         relative_pose = Pose()
        
#     end

# struct PIDGains
#         """
#         Struct to store values of PID gains. Used to transmit controller gain values while instantiating
#         AngleLevel/AngleRate/Velocity/PositionControllerGains objects.
    
#         Attributes:
#             kP (float): Proportional gain
#             kI (float): Integrator gain
#             kD (float): Derivative gain
#         """
#         def __init__(self, kp, ki, kd):
#             self.kp = kp
#             self.ki = ki
#             self.kd = kd
    
#         def to_list(self):
#             return [self.kp, self.ki, self.kd]
    
#     end

# struct AngleRateControllerGains
#         """
#         Struct to contain controller gains used by angle level PID controller
    
#         Attributes:
#             roll_gains (PIDGains): kP, kI, kD for roll axis
#             pitch_gains (PIDGains): kP, kI, kD for pitch axis
#             yaw_gains (PIDGains): kP, kI, kD for yaw axis
#         """
#         def __init__(self, roll_gains = PIDGains(0.25, 0, 0),
#                            pitch_gains = PIDGains(0.25, 0, 0),
#                            yaw_gains = PIDGains(0.25, 0, 0)):
#             self.roll_gains = roll_gains
#             self.pitch_gains = pitch_gains
#             self.yaw_gains = yaw_gains
    
#         def to_lists(self):
#             return [self.roll_gains.kp, self.pitch_gains.kp, self.yaw_gains.kp], [self.roll_gains.ki, self.pitch_gains.ki, self.yaw_gains.ki], [self.roll_gains.kd, self.pitch_gains.kd, self.yaw_gains.kd]
    
#     end

# struct AngleLevelControllerGains
#         """
#         Struct to contain controller gains used by angle rate PID controller
    
#         Attributes:
#             roll_gains (PIDGains): kP, kI, kD for roll axis
#             pitch_gains (PIDGains): kP, kI, kD for pitch axis
#             yaw_gains (PIDGains): kP, kI, kD for yaw axis
#         """
#         def __init__(self, roll_gains = PIDGains(2.5, 0, 0),
#                            pitch_gains = PIDGains(2.5, 0, 0),
#                            yaw_gains = PIDGains(2.5, 0, 0)):
#             self.roll_gains = roll_gains
#             self.pitch_gains = pitch_gains
#             self.yaw_gains = yaw_gains
    
#         def to_lists(self):
#             return [self.roll_gains.kp, self.pitch_gains.kp, self.yaw_gains.kp], [self.roll_gains.ki, self.pitch_gains.ki, self.yaw_gains.ki], [self.roll_gains.kd, self.pitch_gains.kd, self.yaw_gains.kd]
    
#     end

# struct VelocityControllerGains
#         """
#         Struct to contain controller gains used by velocity PID controller
    
#         Attributes:
#             x_gains (PIDGains): kP, kI, kD for X axis
#             y_gains (PIDGains): kP, kI, kD for Y axis
#             z_gains (PIDGains): kP, kI, kD for Z axis
#         """
#         def __init__(self, x_gains = PIDGains(0.2, 0, 0),
#                            y_gains = PIDGains(0.2, 0, 0),
#                            z_gains = PIDGains(2.0, 2.0, 0)):
#             self.x_gains = x_gains
#             self.y_gains = y_gains
#             self.z_gains = z_gains
    
#         def to_lists(self):
#             return [self.x_gains.kp, self.y_gains.kp, self.z_gains.kp], [self.x_gains.ki, self.y_gains.ki, self.z_gains.ki], [self.x_gains.kd, self.y_gains.kd, self.z_gains.kd]
    
#     end

# struct PositionControllerGains
#         """
#         Struct to contain controller gains used by position PID controller
    
#         Attributes:
#             x_gains (PIDGains): kP, kI, kD for X axis
#             y_gains (PIDGains): kP, kI, kD for Y axis
#             z_gains (PIDGains): kP, kI, kD for Z axis
#         """
#         def __init__(self, x_gains = PIDGains(0.25, 0, 0),
#                            y_gains = PIDGains(0.25, 0, 0),
#                            z_gains = PIDGains(0.25, 0, 0)):
#             self.x_gains = x_gains
#             self.y_gains = y_gains
#             self.z_gains = z_gains
    
#         def to_lists(self):
#             return [self.x_gains.kp, self.y_gains.kp, self.z_gains.kp], [self.x_gains.ki, self.y_gains.ki, self.z_gains.ki], [self.x_gains.kd, self.y_gains.kd, self.z_gains.kd]
    
#     end

# struct MeshPositionVertexBuffersResponse
#         position = Vector3r()
#         orientation = Quaternionr()
#         vertices = 0.0
#         indices = 0.0
#         name = ''
# end
