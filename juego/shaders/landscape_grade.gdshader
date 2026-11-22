shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.95, 1.0, 0.90, 1.0);
uniform float warmth = 0.08;
uniform float saturation = 1.12;
uniform float contrast = 1.05;
void fragment() {
 vec4 source = COLOR;
 float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
 vec3 graded = mix(vec3(luminance), source.rgb, saturation);
 graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
 graded = mix(graded, graded * tint.rgb, warmth);
 COLOR = vec4(clamp(graded, 0.0, 1.0), source.a);
}
