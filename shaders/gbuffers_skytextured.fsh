#version 330 compatibility

uniform sampler2D gtexture;
uniform vec3 skyColor;

uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	if (dot(skyColor, skyColor) < 0.001) {
		discard;
	}
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}
}