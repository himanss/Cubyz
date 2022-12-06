#version 430

uniform vec3 ambientLight;
uniform isampler2D fragmentDataSampler;

in vec2 uv;

layout(location = 0) out vec4 fragmentColor;

struct MaterialColor {
	uint diffuse;
	uint emission;
};

struct ProceduralMaterial {
	vec3 simplex1Wavelength;
	float simplex1Weight;

	vec3 simplex2Wavelength;
	vec3 simplex2DomainWarp;
	float simplex2Weight;

	vec3 simplex3Wavelength;
	vec3 simplex3DomainWarp;
	float simplex3Weight;

	float brightnessOffset;

	float randomness;

	MaterialColor colors[8];
};

layout(std430, binding = 5) buffer _materials
{
	ProceduralMaterial materials[];
};


const float[6] normalVariations = float[6](
	1.0, //vec3(0, 1, 0),
	0.85, //vec3(0, -1, 0),
	0.90, //vec3(1, 0, 0),
	0.90, //vec3(-1, 0, 0),
	0.95, //vec3(0, 0, 1),
	0.85 //vec3(0, 0, -1)
);


vec3 unpackColor(uint color) {
	return vec3(color>>16u & 255u, color>>8u & 255u, color & 255u)/255.0;
}

ivec3 random3to3(ivec3 v) {
	ivec3 fac = ivec3(11248723, 105436839, 45399083);
	int seed = v.x*fac.x ^ v.y*fac.y ^ v.z*fac.z;
	v = seed*fac;
	return v;
}

float simplex(vec3 v){
	const vec2 C = vec2(1.0/6.0, 1.0/3.0);

	// First corner
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);

	// Other corners
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);

	// x0 = x0 - 0. + 0.0 * C
	vec3 x1 = x0 - i1 + 1.0*C.xxx;
	vec3 x2 = x0 - i2 + 2.0*C.xxx;
	vec3 x3 = x0 - 1. + 3.0*C.xxx;

	// Get gradients:
	ivec3 rand = random3to3(ivec3(i));
	vec3 p0 = vec3(rand);
	
	rand = random3to3(ivec3(i + i1));
	vec3 p1 = vec3(rand);
	
	rand = random3to3(ivec3(i + i2));
	vec3 p2 = vec3(rand);
	
	rand = random3to3(ivec3(i + 1));
	vec3 p3 = vec3(rand);

	// Mix final noise value
	vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
	m = m*m;
	return (42.0/(1 << 31))*dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

vec3 tripleSimplex(vec3 v){
	const vec2 C = vec2(1.0/6.0, 1.0/3.0);

	// First corner
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);

	// Other corners
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);

	// x0 = x0 - 0. + 0.0 * C
	vec3 x1 = x0 - i1 + 1.0*C.xxx;
	vec3 x2 = x0 - i2 + 2.0*C.xxx;
	vec3 x3 = x0 - 1. + 3.0*C.xxx;


	vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
	m = m*m;
	m = m*m;

	vec3 result = vec3(0);

	{
		// Get gradients:
		ivec3 rand = random3to3(ivec3(i));
		vec3 p0 = vec3(rand);
		
		rand = random3to3(ivec3(i + i1));
		vec3 p1 = vec3(rand);
		
		rand = random3to3(ivec3(i + i2));
		vec3 p2 = vec3(rand);
		
		rand = random3to3(ivec3(i + 1));
		vec3 p3 = vec3(rand);

		// Mix final noise value
		result.x = (42.0/(1 << 31))*dot(m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
	}

	i += 5642.0;
	
	{
		// Get gradients:
		ivec3 rand = random3to3(ivec3(i));
		vec3 p0 = vec3(rand);
		
		rand = random3to3(ivec3(i + i1));
		vec3 p1 = vec3(rand);
		
		rand = random3to3(ivec3(i + i2));
		vec3 p2 = vec3(rand);
		
		rand = random3to3(ivec3(i + 1));
		vec3 p3 = vec3(rand);

		// Mix final noise value
		result.y = (42.0/(1 << 31))*dot(m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
	}

	i -= 11202.0;

	{
		// Get gradients:
		ivec3 rand = random3to3(ivec3(i));
		vec3 p0 = vec3(rand);
		
		rand = random3to3(ivec3(i + i1));
		vec3 p1 = vec3(rand);
		
		rand = random3to3(ivec3(i + i2));
		vec3 p2 = vec3(rand);
		
		rand = random3to3(ivec3(i + 1));
		vec3 p3 = vec3(rand);

		// Mix final noise value
		result.z = (42.0/(1 << 31))*dot(m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
	}

	return result;
}

void main() {
	ivec4 fragmentData = texture(fragmentDataSampler, uv);
	ivec3 voxelPos = fragmentData.xyz;
	int materialIndex = fragmentData.w & 65535;
	if(materialIndex == 0) {
		discard;
	}
	int normal = fragmentData.w >> 16;

	float normalVariation = normalVariations[normal];

	ProceduralMaterial material = materials[materialIndex];

	vec3 randomValues = vec3(random3to3(voxelPos))/(1 << 31);

	vec3 simplex1 = tripleSimplex(voxelPos*material.simplex1Wavelength);
	float simplex2 = simplex(voxelPos*material.simplex2Wavelength + simplex1*material.simplex2DomainWarp);
	float simplex3 = simplex(voxelPos*material.simplex3Wavelength + simplex1*material.simplex3DomainWarp);

	float brightness = simplex1.x*material.simplex1Weight + simplex2*material.simplex2Weight + simplex3*material.simplex3Weight + randomValues.x*material.randomness + material.brightnessOffset + 3;
	int colorIndex = min(7, max(0, int(brightness)));
	fragmentColor.rgb = unpackColor(material.colors[colorIndex].diffuse)*(ambientLight*normalVariation)/4;
	fragmentColor.a = 1;
}