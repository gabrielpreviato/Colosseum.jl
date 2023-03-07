
using MsgPack

abstract type ImageType
end

struct Scene <: ImageType
    property::Int
    Scene(i::Int)=new(0)
    Scene()=new(0)
end

struct DepthPlanar <: ImageType
    property::Int
    DepthPlanar(i::Int)=new(1)
    DepthPlanar()=new(1)
end

struct DepthPerspective <: ImageType
    property::Int
    DepthPerspective(i::Int)=new(2)
    DepthPerspective()=new(2)
end

struct DepthVis <: ImageType
    property::Int
    DepthVis(i::Int)=new(3)
    DepthVis()=new(3)
end

struct DisparityNormalized <: ImageType
    property::Int
    DisparityNormalized(i::Int)=new(4)
    DisparityNormalized()=new(4)
end

struct Segmentation <: ImageType
    property::Int
    Segmentation(i::Int)=new(5)
    Segmentation()=new(5)
end

struct SurfaceNormals <: ImageType
    property::Int
    SurfaceNormals(i::Int)=new(6)
    SurfaceNormals()=new(6)
end

struct Infrared <: ImageType
    property::Int
    Infrared(i::Int)=new(7)
    Infrared()=new(7)
end

struct OpticalFlow <: ImageType
    property::Int
    OpticalFlow(i::Int)=new(8)
    OpticalFlow()=new(8)
end

struct OpticalFlowVis <: ImageType
    property::Int
    OpticalFlowVis(i::Int)=new(9)
    OpticalFlowVis()=new(9)
end

struct ImageRequest
    camera_name::String
    image_type::Int
    pixel_as_float::Bool
    compress::Bool
end

MsgPack.msgpack_type(::Type{ImageRequest}) = MsgPack.StructType()

struct GeoPoint
    latitude::Real 
    longitude::Real
    altitude::Real
end

GeoPoint(msg::Dict{Any, Any}) = GeoPoint(msg["latitude"], msg["longitude"], msg["altitude"])

MsgPack.msgpack_type(::Type{GeoPoint}) = MsgPack.StructType()
MsgPack.from_msgpack(T::Type{GeoPoint}, x::Dict{Any, Any}) = GeoPoint(x)