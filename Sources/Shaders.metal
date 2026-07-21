#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 resolution;
    float time;
    float scanlineIntensity;
    float vignetteIntensity;
    float flickerAmount;
    float noiseAmount;
    float tintR;
    float tintG;
    float tintB;
    float tintStrength;
    float curvatureAmount;
    float lineSpacing;
};

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vertex VertexOut crt_vertex(uint vid [[vertex_id]]) {
    float2 pos[4] = { {-1,-1}, {1,-1}, {-1,1}, {1,1} };
    float2 tex[4] = { {0,1}, {1,1}, {0,0}, {1,0} };

    VertexOut out;
    out.position = float4(pos[vid], 0, 1);
    out.texCoord = tex[vid];
    return out;
}

fragment float4 crt_fragment(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 px = uv * u.resolution;

    float alpha = 0.0;
    float3 color = float3(0.0);

    // Scanlines
    float spacing = max(u.lineSpacing, 1.0);
    float phase = fract(px.y / spacing);
    float scan = smoothstep(0.0, 0.35, phase) * smoothstep(1.0, 0.65, phase);
    alpha += (1.0 - scan) * u.scanlineIntensity * 0.2;

    // Aperture grille - subtle vertical RGB phosphor stripes
    int col = int(px.x) % 3;
    if (col == 0)      color += float3(0.02, 0.0, 0.0) * u.scanlineIntensity;
    else if (col == 1) color += float3(0.0, 0.02, 0.0) * u.scanlineIntensity;
    else               color += float3(0.0, 0.0, 0.02) * u.scanlineIntensity;

    // Vignette
    float2 c = uv - 0.5;
    float d = length(c);
    float vig = smoothstep(0.25, 0.9, d);
    alpha += vig * u.vignetteIntensity * 0.6;

    // Barrel curvature darkening at corners
    float2 e = abs(c) * 2.0;
    float barrel = pow(e.x, 4.0) + pow(e.y, 4.0);
    alpha += barrel * u.curvatureAmount * 0.4;

    // Bezel edge shadow
    float2 edge = smoothstep(float2(0.0), float2(0.012), uv) *
                  smoothstep(float2(0.0), float2(0.012), 1.0 - uv);
    float bezel = 1.0 - edge.x * edge.y;
    alpha += bezel * u.curvatureAmount * 0.8;

    // Flicker
    float flicker = sin(u.time * 50.0) * 0.004
                  + sin(u.time * 83.0) * 0.002
                  + sin(u.time * 7.3) * 0.006;
    alpha += flicker * u.flickerAmount;

    // Static noise
    float n = hash21(px + fract(u.time * 37.7)) * 2.0 - 1.0;
    alpha += n * u.noiseAmount * 0.04;

    // Color tint
    float3 tint = float3(u.tintR, u.tintG, u.tintB);
    color += tint * u.tintStrength;

    alpha = clamp(alpha, 0.0, 0.9);

    // Premultiplied alpha for correct macOS compositing
    return float4(color * alpha, alpha);
}
