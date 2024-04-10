//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include "shader_def.h"

#include <metal_stdlib>
using namespace metal;

struct v2f
{
    float4 position [[position]];
    half4 color;
};

//
//
//
vertex v2f primVert3d( device const VertexDataPrim3D* vertexData [[buffer(0)]],
                       device const Uniforms& cameraData [[ buffer(1)]],
                       uint vID [[vertex_id]])
{
    v2f o;

    const device VertexDataPrim3D& vd = vertexData[ vID ];
    float4 pos = float4( vd.position, 1.0 );
    pos = cameraData.perspectiveTransform * cameraData.worldTransform * pos;
    o.position = pos;
    o.color = vd.color;

    return o;
}

fragment half4 primFrag3d( v2f in [[stage_in]] )
{
    return in.color;
}
