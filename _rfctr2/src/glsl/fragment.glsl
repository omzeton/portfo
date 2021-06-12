uniform samplerCube iChannel0;
uniform float iTime;
uniform vec3 iResolution;
uniform vec2 iMouse;
varying vec2 vUv;
varying vec3 vPosition;

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .001
#define S smoothstep
#define fragCoord gl_FragCoord.xy
#define fragColor gl_FragColor

mat2 Rot(float a) {
    float s=sin(a), c=cos(a);
    return mat2(c, -s, s, c);
}

float sdBox(vec3 p, vec3 s) {
    p = abs(p)-s;
	return length(max(p, 0.))+min(max(p.x, max(p.y, p.z)), 0.);
}


float GetDist(vec3 p) {

    float d = sdBox(p, vec3(1));

    float c = cos(3.1415/5.), s = sqrt(0.75-c*c);
    vec3 n = vec3(-0.5, -c, s);

    p = abs(p);
    p -= 2.*min(0., dot(p, n))*n;

    p.xy = abs(p.xy);
    p -= 2.*min(0., dot(p, n))*n;

    p.xy = abs(p.xy);
    p -= 2.*min(0., dot(p, n))*n;

    d = p.z-1.;

    return d;
}

float RayMarch(vec3 ro, vec3 rd, float side) {
	float dO=0.;
    
    for(int i=0; i<MAX_STEPS; i++) {
    	vec3 p = ro + rd*dO;
        float dS = GetDist(p)*side;
        dO += dS;
        if(dO>MAX_DIST || abs(dS)<SURF_DIST) break;
    }
    
    return dO;
}

vec3 GetNormal(vec3 p) {
	float d = GetDist(p);
    vec2 e = vec2(.01, 0);
    
    vec3 n = d - vec3(
        GetDist(p-e.xyy),
        GetDist(p-e.yxy),
        GetDist(p-e.yyx));
    
    return normalize(n);
}

vec3 GetRayDir(vec2 uv, vec3 p, vec3 l, float z) {
    vec3 f = normalize(l-p),
        r = normalize(cross(vec3(0,1,0), f)),
        u = cross(f,r),
        c = f*z,
        i = c + uv.x*r + uv.y*u,
        d = normalize(i);
    return d;
}

void main() 
{
    vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.y;
	vec2 m = iMouse.xy/iResolution.xy;

    vec3 ro = vec3(0, 3, -3)*.9;
    ro.yz *= Rot(-m.y*3.14+1.);
    ro.xz *= Rot(-m.x*6.2831);
    
    vec3 rd = GetRayDir(uv, ro, vec3(0,0.,0), 1.);
    
    vec3 col = texture(iChannel0, rd).rgb;
   
    float d = RayMarch(ro, rd, 1.); // outside of object
    
    float IOR = 1.45; // index of refraction
    
    if(d<MAX_DIST) {
        vec3 p = ro + rd * d; // 3d hit position
        vec3 n = GetNormal(p); // normal of surface... orientation
        vec3 r = reflect(rd, n);
        vec3 refOutside = texture(iChannel0, r).rgb;
        
        vec3 rdIn = refract(rd, n, 1./IOR); // ray dir when entering
        
        vec3 pEnter = p - n*SURF_DIST*3.;
        float dIn = RayMarch(pEnter, rdIn, -1.); // inside the object
        
        vec3 pExit = pEnter + rdIn * dIn; // 3d position of exit
        vec3 nExit = -GetNormal(pExit); 
        
        vec3 reflTex = vec3(0);
        vec3 rdOut = vec3(0);

        float abb = .01;
        // red
        rdOut = refract(rdIn, nExit, IOR-abb);
        if(dot(rdOut, rdOut)==0.) rdOut = reflect(rdIn, nExit);
        reflTex.r = texture(iChannel0, rdOut).r;
        // green
        rdOut = refract(rdIn, nExit, IOR);
        if(dot(rdOut, rdOut)==0.) rdOut = reflect(rdIn, nExit);
        reflTex.g = texture(iChannel0, rdOut).g;
        // blue
        rdOut = refract(rdIn, nExit, IOR+abb);
        if(dot(rdOut, rdOut)==0.) rdOut = reflect(rdIn, nExit);
        reflTex.b = texture(iChannel0, rdOut).b;

        float dens = .1;
        float opticalDistance = exp(-dIn*dens);

        reflTex = reflTex * opticalDistance; // *vec3(1., .05, .2)

        float fresnel = pow(1.+dot(rd, n), 5.);

        col = mix(reflTex, refOutside, fresnel);

        // col = n*.5+.5;
    }
    
    col = pow(col, vec3(.4545)); // gamma correction
    
    fragColor = vec4(col,1.0);
}
