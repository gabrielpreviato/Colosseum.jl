
using MsgPack
using LinearAlgebra

@enum ImageType Scene=0 DepthPlanar=1 DepthPerspective=2 DepthVis=3 DisparityNormalized=4 Segmentation=5 SurfaceNormals=6 Infrared=7 OpticalFlow=8 OpticalFlowVis=9

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

GeoPoint(msg::Dict{Any, Any}) = GeoPoint(msg["latitude"], msg["longitude"], msg["altitude"])

MsgPack.msgpack_type(::Type{GeoPoint}) = MsgPack.StructType()
MsgPack.from_msgpack(T::Type{GeoPoint}, x::Dict{Any, Any}) = GeoPoint(x)