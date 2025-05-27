#include <metal_stdlib>
#include <simd/simd.h>

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

// Helper function for gamma correction
float3 linearToSRGB(float3 color) {
    return pow(color, 1.0);
}

float3 sRGBToLinear(float3 color) {
    return pow(color, 1.5);
}

// Pass-through vertex shader
vertex VertexOut vertexPassthrough(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Fragment shader to combine RGB texture with Alpha mask with proper gamma correction
fragment float4 combineRGBAlpha(VertexOut in [[stage_in]],
                               texture2d<float> rgbTexture [[texture(0)]],
                               texture2d<float> alphaTexture [[texture(1)]],
                               sampler texSampler [[sampler(0)]]) {
    
    // 1. Sample the RGB color from the main video
    float4 originalRGBColor = rgbTexture.sample(texSampler, in.texCoord);
    
    // 2. Convert from sRGB to linear space for processing
    float3 linearColor = sRGBToLinear(originalRGBColor.rgb);
    
    // 3. Sample the alpha mask video
    float4 alphaMaskColor = alphaTexture.sample(texSampler, in.texCoord);
    
    // 4. Convert the alpha mask's color to grayscale
    float calculatedAlpha = dot(alphaMaskColor.rgb, float3(0.299, 0.587, 0.114));
    
    // 5. Convert back to sRGB space for display
    float3 displayColor = linearToSRGB(linearColor);
    
    // 6. Create the final color
    return float4(displayColor, calculatedAlpha);
}

// Alternative shader with inverted alpha (black = opaque, white = transparent)
fragment float4 combineRGBInvertedAlpha(VertexOut in [[stage_in]],
                                      texture2d<float> rgbTexture [[texture(0)]],
                                      texture2d<float> alphaTexture [[texture(1)]],
                                      sampler texSampler [[sampler(0)]]) {
    
    // 1. Sample the RGB color from the main video
    float4 originalRGBColor = rgbTexture.sample(texSampler, in.texCoord);
    
    // 2. Convert from sRGB to linear space for processing
    float3 linearColor = sRGBToLinear(originalRGBColor.rgb);
    
    // 3. Sample the alpha mask video
    float4 alphaMaskColor = alphaTexture.sample(texSampler, in.texCoord);
    
    // 4. Convert the alpha mask's color to grayscale
    float brightness = dot(alphaMaskColor.rgb, float3(0.299, 0.587, 0.114));
    
    // 5. Invert the brightness to get the alpha value
    float calculatedAlpha = 1.0 - brightness;
    
    // 6. Convert back to sRGB space for display
    float3 displayColor = linearToSRGB(linearColor);
    
    // 7. Create the final color
    return float4(displayColor, calculatedAlpha);
} 
