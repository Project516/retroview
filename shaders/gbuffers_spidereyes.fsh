#version 330 compatibility

uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightLevelData;

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    // Blue 0.5 marks the pixel emissive, so composite leaves it unlit.
    lightLevelData = vec4(0.0, 0.0, 0.5, 1.0);
    // Resource packs may fill eye textures with opaque black, which would cover the body.
    if (color.a < alphaTestRef || max(color.r, max(color.g, color.b)) < 0.01) {
        discard;
    }
}
