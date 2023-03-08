module Colosseum

include("types.jl")



include("client.jl")

export call, reset, getClientVersion, getServerVersion, getMinRequiredServerVersion, getMinRequiredClientVersion,
    enableApiControl, isApiControlEnabled, armDisarm, simPause, simIsPause, simContinueForTime, simContinueForFrames,
    getHomeGeoPoint, confirmConnection, simSetLightIntensity, simSwapTextures, simSetObjectMaterial,
    simSetObjectMaterialFromTexture, simSetTimeOfDay, simEnableWeather, simSetWeatherParameter, simGetImage, simGetImages,
    simGetPresetLensSettings, simGetLensSettings, simSetPresetLensSettings, simGetPresetFilmbackSettings,
    simSetPresetFilmbackSettings, simGetFilmbackSettings, simSetFilmbackSettings, simGetFocalLength, simSetFocalLength,
    simEnableManualFocus, simGetFocusDistance, simSetFocusDistance, simGetFocusAperture, simSetFocusAperture, simEnableFocusPlane,
    simGetCurrentFieldOfView, simTestLineOfSightToPoint, simTestLineOfSightBetweenPoints, simGetWorldExtents, simRunConsoleCommand,
    simGetMeshPositionVertexBuffers, simGetCollisionInfo, simSetVehiclePose, simGetVehiclePose, simSetTraceLine, simGetObjectPose,
    simSetObjectPose, simGetObjectScale, simSetObjectScale, simListSceneObjects, simLoadLevel, simListAssets,
    simSpawnObject, simDestroyObject, simSetSegmentationObjectID, simGetSegmentationObjectID, simAddDetectionFilterMeshName,
    simSetDetectionFilterRadius, simClearDetectionMeshNames, simGetDetections, simPrintLogMessage, simGetCameraInfo,
    simGetDistortionParams, simSetDistortionParams, simSetDistortionParam, simSetCameraPose, simSetCameraFov

end
