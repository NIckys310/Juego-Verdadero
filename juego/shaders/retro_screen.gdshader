shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
 vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
 float scan = 1.0 - 0.045 * (0.5 + 0.5 * cos(FRAGCOORD.y * 3.14159265));
 vec2 edge = SCREEN_UV * 2.0 - 1.0;
 float vignette = 1.0 - 0.075 * dot(edge, edge);
 COLOR = vec4(scene * scan * vignette, 1.0);
}
