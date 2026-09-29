shader_type spatial;
varying vec3 wp;
uniform bool stone = false;
float hash(vec3 p) { return fract(sin(dot(p,vec3(12.98,78.23,37.12)))*43758.54); }
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
    float grain=hash(floor(wp*55.0));
    float ribs=sin(wp.x*32.0+sin(wp.z*28.0)+sin(wp.y*3.0))*0.5+0.5;
    vec3 wood=mix(vec3(0.058,0.038,0.02),vec3(0.20,0.13,0.068),ribs*0.65+grain*0.35);
    vec3 rock=mix(vec3(0.10,0.13,0.115),vec3(0.29,0.32,0.26),grain*0.55+ribs*0.45);
    float moss=(1.0-smoothstep(0.1,1.8,wp.y))*(0.4+sin(wp.x*7.0+wp.z*5.0)*0.3);
    ALBEDO=mix(stone?rock:wood,vec3(0.10,0.17,0.045),moss);
    ROUGHNESS=0.97;
}
