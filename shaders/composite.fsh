#version 330 compatibility

#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

/*
const int colortex0Format = RGB16;
*/

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float retroLevels = 31.0;
uniform float retroDitherStrength = 1.0;
uniform float retroScanStrength = 0.08;
uniform float retroVignetteStrength = 0.25;
uniform float retroVignetteInner = 0.35;
uniform float retroVignetteOuter = 0.90;
uniform float retroPixelScale = 5.0;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const int BAYER4[16] = int[16]
(0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);
float bayer4x4(int ix, int iy) {
	return (BAYER4[iy * 4 + ix] + 0.5) / 16.0;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos) {
	float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);

	if (transparentShadow == 1.0) {
		return vec3(1.0);
	}

	float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.zy).r);

	if (opaqueShadow == 0.0) {
		return vec3(0.0);
	}

	vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
	return shadowColor.rgb * (1.0 - shadowColor.a);
}

void main() {
	vec2 lightmap = texture(colortex1, texcoord).xy;
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

	vec2 screenSize = vec2(textureSize(colortex0, 0));
	vec2 lowUV = floor(texcoord * screenSize / retroPixelScale) * retroPixelScale / screenSize;
	color = texture(colortex0, lowUV);
	color.rgb = pow(color.rgb, vec3(2.2));

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		return;
	}

	vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
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
	vec3 skylight = lightmap.y * skylightColor;
	vec3 ambient = ambientColor;
	vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow;

	color.rgb *= blocklight + skylight + ambient + sunlight;

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

	vec3 bleed = texture(colortex0, lowUV + vec2(0.001, 0.0)).rgb * 0.1;
	color.rgb += bleed * 0.5;

	color.rgb = clamp(color.rgb, 0.0, 1.0);

}