#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform float far;
uniform float fogEnd;
uniform int isEyeInWater;

const float retroLevels = 31.0;
const float retroDitherStrength = 1.0;
const float retroScanStrength = 0.08;
const float retroVignetteStrength = 0.25;
const float retroVignetteInner = 0.35;
const float retroVignetteOuter = 0.90;
const float retroPixelScale = 5.0;

in vec2 texcoord;

const float FOG_DENSITY = 5.0;

const int BAYER4[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
float bayer4x4(int ix, int iy) {
    return (BAYER4[iy * 4 + ix] + 0.5) / 16.0;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    vec2 screenSize = vec2(textureSize(colortex0, 0));
    vec2 lowUV = floor(texcoord * screenSize / retroPixelScale) * retroPixelScale / screenSize;

    color = texture(colortex0, lowUV);
    color.rgb = pow(color.rgb, vec3(2.2));

    float depth = texture(depthtex0, lowUV).r;
    if (depth < 1.0) {
        vec3 ndcPos = vec3(lowUV.xy, depth) * 2.0 - 1.0;
        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);

        // In water, lava or powder snow, use the game's much shorter fog distance.
        float fogDistance = isEyeInWater == 0 ? far : min(far, fogEnd);
        float dist = length(viewPos) / fogDistance;
        float fogFactor = exp(-FOG_DENSITY * (1.0 - dist));

        color.rgb = mix(color.rgb, pow(fogColor, vec3(2.2)), clamp(fogFactor, 0.0, 1.0));
    }

    // Runs after fog and on the sky too, so every pixel gets the same look.
    vec3 srgb = pow(clamp(color.rgb, 0.0, 1.0), vec3(1.0 / 2.2));

    int ix = int(gl_FragCoord.x) & 3;
    int iy = int(gl_FragCoord.y) & 3;
    float b = bayer4x4(ix, iy);
    float offset = (b - 0.5) * (retroDitherStrength / retroLevels);

    vec3 q = floor((srgb + vec3(offset)) * retroLevels + 0.5) / retroLevels;

    color.rgb = pow(clamp(q, 0.0, 1.0), vec3(2.2));

    float rowMod = mod(gl_FragCoord.y, 2.0);
    float scanFactor = mix(1.0 - retroScanStrength, 1.0, step(1.0, rowMod));
    color.rgb *= scanFactor;

    float d = distance(texcoord, vec2(0.5));
    float v = smoothstep(retroVignetteInner, retroVignetteOuter, d);
    color.rgb *= 1.0 - retroVignetteStrength * v;

    color.rgb = clamp(color.rgb, 0.0, 1.0);
}
