#version 330 compatibility

#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

/*
const int colortex0Format = RGB16;
*/

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform bool hasSkylight;

const float retroPixelScale = 5.0;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 moonlightColor = vec3(0.35, 0.45, 0.75);
const float moonlightStrength = 0.05;
const float nightBrightness = 0.15;
const float caveBrightness = 0.05;
const vec3 ambientColor = vec3(0.1);

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos) {
    float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);

    if (transparentShadow == 1.0) {
        return vec3(1.0);
    }

    float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);

    if (opaqueShadow == 0.0) {
        return vec3(0.0);
    }

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
    return shadowColor.rgb * (1.0 - shadowColor.a);
}

void main() {
    vec2 screenSize = vec2(textureSize(colortex0, 0));
    vec2 lowUV = floor(texcoord * screenSize / retroPixelScale) * retroPixelScale / screenSize;

    // Light level L arrives as (L + 0.5) / 16. Remap so level 0 is 0, or
    // unlit caves keep a floor of light.
    vec4 lightData = texture(colortex1, lowUV);
    vec2 lightmap = clamp((lightData.xy * 16.0 - 0.5) / 15.0, 0.0, 1.0);
    // Blue is 0 for lit geometry, 0.5 for glowing eyes and 1 where nothing wrote it.
    bool emissive = abs(lightData.z - 0.5) < 0.25;
    vec3 encodedNormal = texture(colortex2, lowUV).rgb;
    vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
    vec3 lightVector = normalize(shadowLightPosition);
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

    // Iris aims the shadow light at the moon once the sun is down, and the sky
    // lightmap stays lit overnight, so both have to be dimmed by hand to keep
    // night as dark as vanilla.
    //
    // sunPosition and moonPosition arrive in view space, so their .y tracks the
    // camera rather than the horizon. Undo the view rotation to get the real
    // elevation, otherwise the whole world brightens and darkens as you turn.
    vec3 sunDirection = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 moonDirection = normalize(mat3(gbufferModelViewInverse) * moonPosition);
    float sunUp = smoothstep(-0.15, 0.15, sunDirection.y);
    float moonUp = smoothstep(-0.15, 0.15, moonDirection.y);
    float skyBrightness = mix(nightBrightness, 1.0, sunUp);
    vec3 directLight = mix(moonlightColor * moonlightStrength * moonUp, sunlightColor, sunUp);

    color = texture(colortex0, lowUV);
    color.rgb = pow(color.rgb, vec3(2.2));

    float depth = texture(depthtex0, lowUV).r;
    if (depth == 1.0) {
        return;
    }

    // Bleed before lighting so dark areas stay dark.
    color.rgb += texture(colortex0, lowUV + vec2(0.001, 0.0)).rgb * 0.05;

    float depth2 = texture(depthtex2, lowUV).r;
    if (depth >= depth2 && !emissive) {
        vec3 ndcPos = vec3(lowUV.xy, depth) * 2.0 - 1.0;
        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
        vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
        vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
        shadowClipPos.z -= 0.001;
        shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
        vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
        vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

        vec3 shadow = getShadow(shadowScreenPos);

        vec3 blocklight = lightmap.x * blocklightColor;
        vec3 skylight = lightmap.y * skylightColor * skyBrightness;
        // The sky lightmap is 0 underground. Scaling by it keeps caves dark,
        // even where the shadow map misses the terrain overhead. The Nether and
        // End have no sky light, so they skip it.
        float skyAccess = hasSkylight ? lightmap.y : 1.0;
        vec3 ambient = ambientColor * mix(caveBrightness, skyBrightness, skyAccess);
        vec3 direct = directLight * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow * skyAccess;

        color.rgb *= blocklight + skylight + ambient + direct;
    }
}
