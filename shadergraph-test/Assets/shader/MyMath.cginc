//return 1 if a >= b
float IsLessEqualThan(float a, float b){
	return (a - b >= 0)? 1.:0.;
}

float3 InverseGammaConversion(float3 rgb){
	float gamma = 1.0 / 2.2;
	float3 c = rgb;
	c.rgb = float3(pow(c.r,1.0 / gamma), pow(c.g, 1.0 / gamma), pow(c.b, 1.0 / gamma ));
	return c;
}

float GammaConversion(float v){
	float gamma = 1.0 / 2.2;
	return pow(v,gamma);
}

float3 GammaConversion(float3 rgb){
	float3 c = rgb;
	c.rgb = float3(GammaConversion(c.r), GammaConversion(c.g), GammaConversion(c.b));
	return c;
}

//CIE XYZのYを利用したグレイスケール
//https://qiita.com/yoya/items/96c36b069e74398796f3
float GetGrayScale(float3 color){
	float3 c = color;
	c = InverseGammaConversion(c);
	float vDash = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
	return GammaConversion(vDash);
}

//ランダムノイズ
//https://qiita.com/shimacpyon/items/d15dee44a0b8b3883f76
//https://gist.github.com/johansten/3633917
float Random(fixed2 v){
	float a = frac(dot(v.xy, float2(2.067390879775102, 12.451168662908249))) - 0.5;
	float s = a * (6.182785114200511 + a*a * (-38.026512460676566 + a*a * 53.392573080032137));
	return frac(s * 43758.5453);
}

//ブロックノイズ
float BlockNoise(fixed2 pos){
	fixed2 p = floor(pos);
	return Random(p);
}

//バリューノイズ
float ValueNoise(fixed2 pos){
	fixed2 p = floor(pos);
	fixed2 f = frac(pos);

	float v00 = Random( (p + fixed2(0,0)) );
	float v10 = Random(p + fixed2(1,0));
	float v01 = Random(p + fixed2(0,1));
	float v11 = Random(p + fixed2(1,1));

	fixed2 u = f * f * (3.0 - 2.0 * f);

	float v0010 = lerp(v00,v10,u.x);
	float v0111 = lerp(v01,v11,u.x);
	return lerp(v0010, v0111, u.y);
}




//パーリンノイズ
//http://www.shaderslab.com/demo-74---2d-perlin-noise3D.html

float4 permute(float4 x)
{
	return fmod(34.0 * pow(x, 2) + x, 289.0);
}

float2 fade(float2 t) {
	return 6.0 * pow(t, 5.0) - 15.0 * pow(t, 4.0) + 10.0 * pow(t, 3.0);
}

float4 taylorInvSqrt(float4 r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}

#define DIV_289 0.00346020761245674740484429065744f

float mod289(float x) {
	return x - floor(x * DIV_289) * 289.0;
}

float PerlinNoise2D(float2 P)
{
		float4 Pi = floor(P.xyxy) + float4(0.0, 0.0, 1.0, 1.0);
		float4 Pf = frac (P.xyxy) - float4(0.0, 0.0, 1.0, 1.0);

		float4 ix = Pi.xzxz;
		float4 iy = Pi.yyww;
		float4 fx = Pf.xzxz;
		float4 fy = Pf.yyww;

		float4 i = permute(permute(ix) + iy);

		float4 gx = frac(i / 41.0) * 2.0 - 1.0 ;
		float4 gy = abs(gx) - 0.5 ;
		float4 tx = floor(gx + 0.5);
		gx = gx - tx;

		float2 g00 = float2(gx.x,gy.x);
		float2 g10 = float2(gx.y,gy.y);
		float2 g01 = float2(gx.z,gy.z);
		float2 g11 = float2(gx.w,gy.w);

		float4 norm = taylorInvSqrt(float4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
		g00 *= norm.x;
		g01 *= norm.y;
		g10 *= norm.z;
		g11 *= norm.w;

		float n00 = dot(g00, float2(fx.x, fy.x));
		float n10 = dot(g10, float2(fx.y, fy.y));
		float n01 = dot(g01, float2(fx.z, fy.z));
		float n11 = dot(g11, float2(fx.w, fy.w));

		float2 fade_xy = fade(Pf.xy);
		float2 n_x = lerp(float2(n00, n01), float2(n10, n11), fade_xy.x);
		float n_xy = lerp(n_x.x, n_x.y, fade_xy.y);
		return 2.3 * n_xy;
}

float fBm(fixed2 pos){
	float f = 0;
	fixed2 p = pos;

	f += 0.5000 * (PerlinNoise2D(p)/2 + .5);p *= 2.01;
	f += 0.2500 * (PerlinNoise2D(p)/2 + .5);
	p *= 2.02;
	f += 0.1250 * (PerlinNoise2D(p)/2 + .5);
	p *= 2.03;
	f += 0.0625 * (PerlinNoise2D(p)/2 + .5);
	p *= 2.01;
	return f;
}


float rand(float3 co)
{
	return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 56.787))) * 43758.5453);
}

float noise3D(float3 pos)
{
	float3 ip = floor(pos);
	float3 fp = smoothstep(0, 1, frac(pos));
	float4 a = float4(
		rand(ip + float3(0, 0, 0)),
		rand(ip + float3(1, 0, 0)),
		rand(ip + float3(0, 1, 0)),
		rand(ip + float3(1, 1, 0)));
	float4 b = float4(
		rand(ip + float3(0, 0, 1)),
		rand(ip + float3(1, 0, 1)),
		rand(ip + float3(0, 1, 1)),
		rand(ip + float3(1, 1, 1)));
 
	a = lerp(a, b, fp.z);
	a.xy = lerp(a.xy, a.zw, fp.y);
	return lerp(a.x, a.y, fp.x);
}
float pnoise3D(float3 pos)
{
	return 
		(noise3D(pos) +
		noise3D(pos * 2 ) +
		noise3D(pos * 4) +
		noise3D(pos * 8) +
		noise3D(pos * 16) +
		noise3D(pos * 32) ) / 6;
}

float3x3 m = float3x3( 0.00,  0.80,  0.60,-0.80,  0.36, -0.48,-0.60, -0.48,  0.64);

float fBm3D(float3 p)
{
    float f;
    f  = 0.5000 * pnoise3D(p); p = mul(m,p)  * 2.02;
    f += 0.2500 * pnoise3D(p); p = mul(m,p) * 2.03;
    f += 0.1250 * pnoise3D(p);
    return f;
}