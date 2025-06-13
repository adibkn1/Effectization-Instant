#include <metal_stdlib>
using namespace metal;

// Vertex shader outputs and fragment shader inputs
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Vertex input for a simple quad
struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

// Pass-through vertex shader
vertex VertexOut vertexPassthrough(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 combineRGBAlpha(
    VertexOut                       in               [[stage_in]],
    texture2d<float, access::sample> rgbTex          [[texture(0)]],
    texture2d<float, access::sample> maskTex         [[texture(1)]],
    sampler                         samp             [[sampler(0)]])
{
    float4 rgb   = rgbTex.sample(samp, in.texCoord);   // already linear due to _srgb format
    float  alpha = maskTex.sample(samp, in.texCoord).r;

    float3 premul = rgb.rgb * alpha;                   // premultiply
    return float4(premul, alpha);                      // Metal writes linear; display converts to sRGB
}

fragment float4 combineRGBInvertedAlpha(
    VertexOut                       in               [[stage_in]],
    texture2d<float, access::sample> rgbTex          [[texture(0)]],
    texture2d<float, access::sample> maskTex         [[texture(1)]],
    sampler                         samp             [[sampler(0)]])
{
    float4 rgb   = rgbTex.sample(samp, in.texCoord);   // already linear due to _srgb format
    float  alpha = 1.0 - maskTex.sample(samp, in.texCoord).r;  // inverted alpha

    float3 premul = rgb.rgb * alpha;                   // premultiply
    return float4(premul, alpha);                      // Metal writes linear; display converts to sRGB
}

// New shader for correct RGB+Alpha compositing
fragment float4 combineRGBAlphaWithTransparency(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> rgbTex [[texture(0)]],
    texture2d<float, access::sample> maskTex [[texture(1)]],
    sampler samp [[sampler(0)]])
{
    float4 rgb = rgbTex.sample(samp, in.texCoord);
    float alpha = maskTex.sample(samp, in.texCoord).r;
    return float4(rgb.rgb, rgb.a * alpha);
} 
