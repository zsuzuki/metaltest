//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include "shader_def.h"

#include <metal_stdlib>
using namespace metal;

struct v2f
{
    float4 position [[position]];
    float3 normal;
    half3 color;
    float2 texcoord;
};

//
//
//
vertex v2f simpleVert3d(device const VertexData3D* vertexData [[buffer(0)]],
                       device const Uniforms& cameraData [[buffer(1)]],
                       uint vertexId [[vertex_id]])
{
    v2f o;

    const device VertexData3D& vd = vertexData[ vertexId ];

    float4 pos = float4( vd.position, 1.0 );
    o.position = cameraData.perspectiveTransform * cameraData.worldTransform * pos;
    o.normal   = cameraData.worldNormalTransform * vd.normal;
    o.texcoord = vd.texcoord.xy;
    o.color    = vd.color.rgb;

    return o;
}

fragment half4 simpleFrag3d( v2f in [[stage_in]], texture2d< half, access::sample > tex [[texture(0)]] )
{
    constexpr sampler s( address::repeat, filter::linear );

    half4 texel = tex.sample( s, in.texcoord ).rgba;

    // assume light coming from (front-top-right)
    float3 l = normalize(float3( 1.0, 1.0, 0.8 ));
    float3 n = normalize( in.normal );

    half ndotl = half( saturate( dot( n, l ) ) );

    half3 illum = (in.color * texel.xyz * 0.1) + (in.color * texel.xyz * ndotl);

    return half4( illum, texel.a );
}
