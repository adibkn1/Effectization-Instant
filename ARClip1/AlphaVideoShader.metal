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

// Helper function to convert sRGB to linear space
float3 sRGBToLinear(float3 srgb) {
    return pow(srgb, 2.2);
}

// Helper function to convert linear to sRGB space
float3 linearToSRGB(float3 linear) {
    return pow(linear, 1.0/2.2);
}

// Main fragment shader for RGB+Alpha compositing
fragment float4 combineRGBAlphaWithTransparency(
    VertexOut in [[stage_in]],
    texture2d<float> rgbTex [[texture(0)]],
    texture2d<float> alphaTex [[texture(1)]],
    sampler samp [[sampler(0)]])
{
    // Sample RGB and alpha textures
    float4 rgbColor = rgbTex.sample(samp, in.texCoord);
    float4 alphaColor = alphaTex.sample(samp, in.texCoord);
    
    // Convert RGB from sRGB to linear space for proper blending
    float3 linearRGB = sRGBToLinear(rgbColor.rgb);
    
    // Calculate alpha from the alpha texture (using red channel)
    float alpha = alphaColor.r;
    
    // Pre-multiply RGB by alpha
    float3 premultipliedRGB = linearRGB * alpha;
    
    // Convert back to sRGB space for output
    float3 outputRGB = linearToSRGB(premultipliedRGB);
    
    // Return final color with alpha
    return float4(outputRGB, alpha);
}

// Legacy shaders kept for reference
fragment float4 combineRGBAlpha(
    VertexOut in [[stage_in]],
    texture2d<float> rgbTex [[texture(0)]],
    texture2d<float> maskTex [[texture(1)]],
    sampler samp [[sampler(0)]])
{
    float4 rgb = rgbTex.sample(samp, in.texCoord);
    float alpha = maskTex.sample(samp, in.texCoord).r;
    float3 premul = rgb.rgb * alpha;
    return float4(premul, alpha);
}

fragment float4 combineRGBInvertedAlpha(
    VertexOut in [[stage_in]],
    texture2d<float> rgbTex [[texture(0)]],
    texture2d<float> maskTex [[texture(1)]],
    sampler samp [[sampler(0)]])
{
    float4 rgb = rgbTex.sample(samp, in.texCoord);
    float alpha = 1.0 - maskTex.sample(samp, in.texCoord).r;
    float3 premul = rgb.rgb * alpha;
    return float4(premul, alpha);
} 
