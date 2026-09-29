shader_type spatial;
render_mode diffuse_burley;
uniform vec2 route[6];
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_pos.xz;
    float d=100.0;
    for(int i=0;i<5;i++) {
        vec2 a=route[i], b=route[i+1];
        float t=clamp(dot(p-a,b-a)/dot(b-a,b-a),0.0,1.0);
        d=min(d,length(p-mix(a,b,t)));
    }
    float edge=noise(p*1.7)*0.4+noise(p*0.35)*0.7;
    float path=1.0-smoothstep(1.05,1.95,d+edge);
    float clear_a=1.0-smoothstep(3.9,5.5,length(p-vec2(-9,5))+edge);
    float clear_b=1.0-smoothstep(3.9,5.5,length(p-vec2(10,-12))+edge);
    path=max(path,max(clear_a,clear_b)*0.85);
    float grain=noise(p*30.0), broad=noise(p*0.7), leaves=noise(p*9.0);
    vec3 moss=mix(vec3(0.045,0.07,0.026),vec3(0.14,0.18,0.065),broad);
    vec3 soil=mix(vec3(0.08,0.053,0.029),vec3(0.25,0.19,0.105),grain*0.45+broad*0.55);
    ALBEDO=mix(moss,soil,path)*(0.74+grain*0.4);
    ALBEDO+=vec3(0.065,0.037,0.008)*step(0.73,leaves)*(1.0-path*0.6);
    ROUGHNESS=0.94;
}
