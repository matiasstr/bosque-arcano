shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform float wind_strength = 0.04;
varying float variation;
void vertex(){
    vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float weight=clamp(VERTEX.y,0.0,1.0);
    VERTEX.x+=sin(TIME*1.3+wp.x*0.5+wp.z*0.2)*wind_strength*weight;
    VERTEX.z+=cos(TIME*0.9+wp.z*0.4)*wind_strength*0.5*weight;
    variation=sin(wp.x*3.1+wp.z*7.2)*0.07;
}
void fragment(){
    ALBEDO=COLOR.rgb*(0.85+UV.y*0.25+variation);
    ROUGHNESS=0.88;
    BACKLIGHT=ALBEDO*0.25;
}
