import MetalKit

private let shaderSource = """
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
    float rgbDarkness;
    float rgbColor;
    float vhsAmount;
    float staticJump;
    float sizeScale;
    float intensity;
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
    float t = u.time;
    float scale = 0.25 + u.sizeScale * 3.75;

    // Accumulate premultiplied RGBA directly per effect
    float4 result = float4(0.0);

    // === Scanlines ===
    float spacing = max(u.lineSpacing, 1.0) * scale;
    float phase = fract(px.y / spacing);
    float scan = smoothstep(0.0, 0.35, phase) * smoothstep(1.0, 0.65, phase);
    result.a += (1.0 - scan) * u.scanlineIntensity * 0.4;

    // === RGB pixel grid ===
    if (u.rgbDarkness > 0.001 || u.rgbColor > 0.001) {
        float gridSize = 2.0 * scale;
        float2 cell = floor(px / gridSize);
        float2 local = fract(px / gridSize);

        // Gap between cells
        float gapX = 1.0 - step(0.1, local.x) * (1.0 - step(0.9, local.x));
        float gapY = 1.0 - step(0.1, local.y) * (1.0 - step(0.9, local.y));
        float isGap = max(gapX, gapY);
        float isCell = 1.0 - isGap;

        // Dark gap borders
        result.a += isGap * u.rgbDarkness * 0.375;

        // Colored cells: strong premultiplied color
        int ch = int(cell.x) % 3;
        float3 rgb = float3(0.0);
        if (ch == 0)      rgb = float3(1.0, 0.0, 0.0);
        else if (ch == 1) rgb = float3(0.0, 1.0, 0.0);
        else              rgb = float3(0.0, 0.0, 1.0);
        float cellA = isCell * u.rgbColor * 0.375;
        result.rgb += rgb * cellA;
        result.a += cellA;
    }

    // === Vignette ===
    float2 c = uv - 0.5;
    float d = length(c);
    float vig = smoothstep(0.25, 0.9, d);
    result.a += vig * u.vignetteIntensity * 1.2;

    // === Barrel curvature darkening ===
    float2 e = abs(c) * 2.0;
    float barrel = pow(e.x, 4.0) + pow(e.y, 4.0);
    result.a += barrel * u.curvatureAmount * 0.8;

    // === Bezel edge shadow ===
    float2 edge = smoothstep(float2(0.0), float2(0.012), uv) *
                  smoothstep(float2(0.0), float2(0.012), 1.0 - uv);
    float bezel = 1.0 - edge.x * edge.y;
    result.a += bezel * u.curvatureAmount * 1.6;

    // === Flicker ===
    float flicker = sin(t * 8.0) * 0.3
                  + sin(t * 13.7) * 0.16
                  + sin(t * 3.1) * 0.24;
    result.a += flicker * u.flickerAmount;

    // === Static noise ===
    float n = hash21(px + fract(t * 37.7)) * 2.0 - 1.0;
    result.a += n * u.noiseAmount * 0.08;

    // === VHS distortion ===
    if (u.vhsAmount > 0.001) {
        float vScale = scale;

        // Tracking lines
        float trackPhase = uv.y * (5.0 / vScale) + t * 0.15 + sin(t * 0.3) * 0.5;
        float trackLine = pow(abs(sin(trackPhase * 3.14159)), 20.0);
        result.a += trackLine * u.vhsAmount * 0.06;

        // Horizontal jitter
        float jitterSeed = floor(t * 8.0);
        float lineHash = hash21(float2(floor(px.y / (3.0 * vScale)), jitterSeed));
        float jitter = step(0.96, lineHash) * (lineHash - 0.96) * 25.0;
        result.a += jitter * u.vhsAmount * 0.125;

        // Head switching noise
        float headY = 0.92 + sin(t * 1.3) * 0.04;
        float headBand = 1.0 - smoothstep(0.0, 0.03 * vScale, abs(uv.y - headY));
        float headNoise = hash21(float2(px.x * 0.3, floor(t * 30.0)));
        float headA = headBand * headNoise * u.vhsAmount * 0.125;
        result.rgb += float3(0.1, 0.0, 0.06) * headA;
        result.a += headA;

        // Color bleeding
        float bleedPhase = fract(px.y / (8.0 * vScale) + t * 0.05);
        float3 bleed = float3(0.0);
        if (bleedPhase < 0.33) bleed = float3(0.04, 0.0, 0.0);
        else if (bleedPhase > 0.66) bleed = float3(0.0, 0.0, 0.04);
        float bleedA = u.vhsAmount * 0.012;
        result.rgb += bleed * bleedA;
        result.a += bleedA * 0.15;

        // Random glitch burst
        float glitchSeed = floor(t * 1.5);
        float glitchRand = hash21(float2(glitchSeed, 99.0));
        float glitchOn = step(0.85, glitchRand);
        float glitchY = hash21(float2(glitchSeed, 77.0));
        float glitchH = hash21(float2(glitchSeed, 55.0)) * 0.06 + 0.005;
        float inGlitch = step(glitchY, uv.y) * step(uv.y, glitchY + glitchH);
        float glitchNoise = hash21(px + t * 500.0);
        float glitchA = inGlitch * glitchOn * glitchNoise * u.vhsAmount * 0.15;
        result.rgb += float3(0.04, 0.02, 0.0) * glitchA;
        result.a += glitchA;

        // Dropout lines
        float dropSeed = floor(t * 4.0);
        float dropRand = hash21(float2(floor(px.y / vScale), dropSeed));
        float isDrop = step(0.998, dropRand);
        float dropA = isDrop * u.vhsAmount * 0.037;
        result.rgb += float3(0.1) * dropA;
        result.a += dropA;

        // Wavy wobble
        float wobble = sin(uv.y * (40.0 / vScale) + t * 2.0) * sin(t * 0.7) * 0.003;
        float wobbleEdge = smoothstep(0.0, 0.01, abs(wobble));
        result.a += (1.0 - wobbleEdge) * u.vhsAmount * 0.05;
    }

    // === Static jump ===
    if (u.staticJump > 0.001) {
        float sjScale = scale;

        // Horizontal tear lines
        float tearSeed = floor(t * 6.0);
        float tearY = hash21(float2(tearSeed, 31.0));
        float tearLine = 1.0 - smoothstep(0.0, 0.003 * sjScale, abs(uv.y - tearY));
        float tearOn = step(0.8, hash21(float2(tearSeed, 67.0)));
        result.a += tearLine * tearOn * u.staticJump * 0.3;

        // Static noise bursts in random blocks
        float burstSeed = floor(t * 2.0);
        float burstOn = step(0.85, hash21(float2(burstSeed, 88.0)));
        float blockX = floor(px.x / (20.0 * sjScale));
        float blockY = floor(px.y / (8.0 * sjScale));
        float blockNoise = hash21(float2(blockX, blockY) + t * 100.0);
        float burstA = burstOn * blockNoise * u.staticJump * 0.25;
        result.rgb += float3(0.06) * burstA;
        result.a += burstA;

        // Rolling black bar
        float rollPhase = fract(t * 0.4);
        float rollBar = 1.0 - smoothstep(0.0, 0.06, abs(uv.y - rollPhase));
        float rollOn = step(0.7, hash21(float2(floor(t * 0.4), 55.0)));
        result.a += rollBar * rollOn * u.staticJump * 0.2;

        // Frame jump: brief dark band at random Y
        float jumpSeed = floor(t * 3.0);
        float jumpOn = step(0.88, hash21(float2(jumpSeed, 42.0)));
        float jumpY = hash21(float2(jumpSeed, 13.0));
        float jumpBand = 1.0 - smoothstep(0.0, 0.04, abs(uv.y - jumpY));
        result.a += jumpBand * jumpOn * u.staticJump * 0.35;
    }

    // === Color tint: tints proportionally to darkened area ===
    float3 tint = float3(u.tintR, u.tintG, u.tintB);
    result.rgb += tint * u.tintStrength * result.a;

    // Master intensity: 0.5 = normal, 1.0 = 2x, 0.0 = off
    float masterScale = u.intensity * 2.0;
    result *= masterScale;

    // Clamp and enforce premultiplied constraint
    result.a = clamp(result.a, 0.0, 0.95);
    result.rgb = clamp(result.rgb, float3(0.0), float3(result.a));
    return result;
}
"""

class CRTMetalView: MTKView, MTKViewDelegate {
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var startTime: CFAbsoluteTime = 0

    struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var scanlineIntensity: Float
        var vignetteIntensity: Float
        var flickerAmount: Float
        var noiseAmount: Float
        var tintR: Float
        var tintG: Float
        var tintB: Float
        var tintStrength: Float
        var curvatureAmount: Float
        var lineSpacing: Float
        var rgbDarkness: Float
        var rgbColor: Float
        var vhsAmount: Float
        var staticJump: Float
        var sizeScale: Float
        var intensity: Float
    }

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        setup()
    }

    required init(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }

    private func setup() {
        guard let device = self.device else { return }

        self.delegate = self
        self.preferredFramesPerSecond = 30
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        self.colorPixelFormat = .bgra8Unorm
        self.layer?.isOpaque = false
        (self.layer as? CAMetalLayer)?.isOpaque = false

        commandQueue = device.makeCommandQueue()
        let library = try! device.makeLibrary(source: shaderSource, options: nil)

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "crt_vertex")
        desc.fragmentFunction = library.makeFunction(name: "crt_fragment")
        desc.colorAttachments[0].pixelFormat = self.colorPixelFormat

        pipelineState = try! device.makeRenderPipelineState(descriptor: desc)
        startTime = CFAbsoluteTimeGetCurrent()
    }

    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor else { return }

        let s = CRTSettings.shared
        // Wrapped, and in Double before the wrap. The shader feeds time into
        // hash21 (t * 500 for the VHS glitch, t * 100 for static blocks, floor(t)
        // seeds elsewhere), and hash21 multiplies by about 456 before fract():
        // past roughly 2 minutes of uptime the Float products lost every
        // fractional bit, so the glitch noise, static bursts, tearing and jitter
        // froze or vanished one by one. Measured working through 90 s, dead from
        // about 136 s, so a 60 s cycle stays inside the range that works. The
        // wrap reseeds the noise and moves the slow VHS bands once a minute,
        // which reads as one more tracking glitch.
        let time = Float((CFAbsoluteTimeGetCurrent() - startTime).truncatingRemainder(dividingBy: 60))

        var uniforms = Uniforms(
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
            time: time,
            scanlineIntensity: s.scanlineIntensity,
            vignetteIntensity: s.vignetteIntensity,
            flickerAmount: s.flickerAmount,
            noiseAmount: s.noiseAmount,
            tintR: s.tintR,
            tintG: s.tintG,
            tintB: s.tintB,
            tintStrength: s.tintStrength,
            curvatureAmount: s.curvatureAmount,
            lineSpacing: s.lineSpacing,
            rgbDarkness: s.rgbDarkness,
            rgbColor: s.rgbColor,
            vhsAmount: s.vhsAmount,
            staticJump: s.staticJump,
            sizeScale: s.sizeScale,
            intensity: s.intensity
        )

        guard let buffer = commandQueue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        encoder.setRenderPipelineState(pipelineState)
        // stride, not size: the shader's struct is padded to 80 bytes, and Metal
        // validation rejects a 76-byte binding.
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
