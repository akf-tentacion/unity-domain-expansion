Shader "Unlit/MyCloud"
{
    Properties
    {
        _MainTex("dummytex",2D) = "White"{}
        _Color("Color", Color) = (1,1,1,1)
        [PowerSlider(10.0)] _Step("Step", Range(0.001, 0.1)) = 0.03
        _LightColor0("LightColor0", Color) = (1,1,1,1)
        [IntRange] _Loop("Loop", Range(0,128)) = 32
        _NoiseScale("NoiseScale",  Range(0,100)) = 10
        _Absorption("Absorption",Range(0,100)) = 50
        _Opacity("Opacity", Range(0,100)) = 100
        _AbsorptionLight("AbsorptionLight", Range(0,100)) = 50
        _OpacityLight("OpacityLight",Range(0,100)) = 50
        _LightStepScale("LightStepScale",Range(0,1)) = 0.5
        [IntRange] _LoopLight("LoopLight",Range(0,128)) = 6

        _SmokeNoiseScale("smokeNoiseScale",Range(0,10)) = 2.0
        _SmokeNoiseSwarl("SmokeNoiseVal",Range(0,10)) = 0.5
    }

    CGINCLUDE 

    #include "UnityCG.cginc"
    #include "SmokeNoise.cginc"

    struct appdata
    {
        float4 vertex : POSITION;
    };

    struct v2f
    {
        float4 vertex   : SV_POSITION;
        float3 worldPos : TEXCOORD1;
        float4 projPos  : TEXCOORD2;
    };

    #define MAX_LOOP 100
    sampler2D _MainTex;
    float4 _MainTex_ST;
    float4  _Color,
            _LightColor0;

    float   _NoiseScale,
            _Absorption,
            _Opacity,
            _AbsorptionLight,
            _OpacityLight,
            _LightStepScale,
            _SmokeNoiseScale,
            _SmokeNoiseSwarl,
            _Step;

    int     _Loop,
            _LoopLight;
    
    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

    //inline 化で小さい関数の呼び出しが効率化される
    // https://www.shadertoy.com/view/lss3zr
    inline float hash(float n )
    {
        return frac(sin(n) * 43758.5453);
    }

    inline float noise(float3 x)
    {
        float3 p = floor(x);
        float3 f = frac(x);

        f = f * f * (3.0 - 2.0 * f);
        float n = p.x + p.y * 57.0 + 113.0 * p.z;

        float res = lerp(lerp(lerp(hash(n +   0.0), hash(n +   1.0), f.x),
                  lerp(hash(n +  57.0), hash(n +  58.0), f.x), f.y),
             lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                  lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
        return res;
    }

    inline float fbm(float3 p)
    {
        float3x3 m = float3x3( 0.00,  0.80,  0.60,-0.80,  0.36, -0.48,-0.60, -0.48,  0.64);
        float f;
        f  = 0.5000 * noise(p); p = mul(m,p) * 2.02;
        f += 0.3 * noise(p); p = mul(m,p) * 2.03;
        f += 0.2 * noise(p);
        return f;
    }

    inline float torus(float3 p, float2 radius)
    {
        float3 pos = p;
        float2 r = float2(length(pos.xy) - radius.x, pos.z);
        return length(r) - radius.y;
    }

    inline float opSubtraction( float d1, float d2 ) 
    {
        return max(-d1,d2);
    }

    inline float box( float3 p, float3 b )
    {
        float f1 =  length(max(abs(p) - b,0.0));
        return max(f1,f1);
    }

    inline float sphere(float3 pos, float radius)
    {
        return length(pos) - radius;
    }

    inline float sdCappedCylinder( float3 p, float h, float r )
    {
        float2 d = abs(float2(length(p.xy),p.z)) - float2(h,r);
        return min(max(d.x,d.y),0.0) + length(max(d,0.0));
    }

    inline float densityFunction3(float3 p){

        float f = fbm(p * _NoiseScale);
        float d2 = -torus(p, float2(0.5, 0.02)) + f * 0.2;
        return d2;

        //return fbm(p * _NoiseScale) - length(p / _Radius);
    }

    inline float densityFunction(float3 p){

        float noise = getNoise(p.xyz * _SmokeNoiseScale - _Time.w * 0.01,_SmokeNoiseSwarl );
        noise = noise * noise * noise * noise;  //more contrast

        //float f = fbm(noise * _NoiseScale);
        //float sp = sdCappedCylinder(p,0.15,0.25);
        //if(sp <= 0.01){
         //   return 1;
       // }

        float d1 = -torus(p, float2(0.5, 0.05)) + noise * 0.7;
        float d2 = -box(p, float3(0.35,0.08,0.005)) + noise * 0.01 * _NoiseScale;
        return d2;

        //return fbm(p * _NoiseScale) - length(p / _Radius);
    }
    
    inline float densityFunction2(float3 p){

        float noise = getNoise(p.xyz * _SmokeNoiseScale+ _Time.w * 0.01,_SmokeNoiseSwarl );
        noise = noise * noise * noise * noise;  //more contrast

        float f = fbm(noise * _NoiseScale);
        float sp = sdCappedCylinder(p,0.15,0.25);
        //if(sp <= 0.01){
         //   return 1;
       // }

        float d1 = -torus(p, float2(0.5, 0.05)) + f * 0.2;
        float d2 = -box(p, float3(0.35,0.08,0.005)) + f * 0.2;
        return d2;

        //return fbm(p * _NoiseScale) - length(p / _Radius);
    }
    

    v2f vert(appdata v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
        o.projPos = ComputeScreenPos(o.vertex);
        COMPUTE_EYEDEPTH(o.projPos.z);
        return o;
    }


    void sample(
        float3 pos, 
        float step, 
        float lightStep,
        inout float4 color,
        inout float transmittance)
    {
        float density = densityFunction(pos);
        if (density < 0.0) return;

        float d = density * step;
        transmittance *= 1.0 - d * _Absorption;
        if (transmittance < 0.01) return;

        float transmittanceLight = 1.0;
        float3 lightPos = pos;
        for (int j = 0; j < _LoopLight; ++j)
        {
            float densityLight = densityFunction(lightPos);
            if (densityLight > 0.0)
            {
                float dl = densityLight * lightStep;
                transmittanceLight *= 1.0 - dl * _AbsorptionLight;
                if (transmittanceLight < 0.01) 
                {
                    transmittanceLight = 0.0;
                    break;
                }
            }
            lightPos += lightStep;
        }

        color.a += _Color.a * (_Opacity * d * transmittance);
        color.rgb += _LightColor0 * (_OpacityLight * d * transmittance * transmittanceLight);
        color = clamp(color, 0.0, 1.0);
    }
    
    float4 frag(v2f i) : SV_TARGET
    {  
        float3 worldPos = i.worldPos;
        float3 camToWorldPos = worldPos - _WorldSpaceCameraPos;
        float3 worldDir = normalize(camToWorldPos);

        float3 localPos = mul(unity_WorldToObject, float4(worldPos, 1.0));
        float3 localDir = UnityWorldToObjectDir(worldDir);
        float3 localStep = localDir * _Step;
        localPos += (_Step - fmod(length(UnityWorldToObjectDir(camToWorldPos)), _Step)) * localDir;
        float jitter = hash(localPos.x + localPos.y * 1000 + localPos.z * 10000 + _Time.x);
        localPos += jitter * localStep;

        float3 invLocalDir = 1.0 / localDir;
        float3 t1 = (-0.5 - localPos) * invLocalDir;
        float3 t2 = (+0.5 - localPos) * invLocalDir;
        float3 tmax3 = max(t1, t2);
        float2 tmax2 = min(tmax3.xx, tmax3.yz);
        float traverseDist = min(tmax2.x, tmax2.y);
        int loop = floor(traverseDist / _Step);

        float lightStep = 1.0 / _LoopLight;
        float3 localLightDir = UnityWorldToObjectDir(_WorldSpaceLightPos0.xyz);
        float3 localLightStep = localLightDir * lightStep * _LightStepScale;

        float depth = LinearEyeDepth(
            SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
        float3 cameraForward = -UNITY_MATRIX_V[2].xyz;
        float cameraToDepth = depth / dot(worldDir, cameraForward);
        float cameraToStart = length(worldPos - _WorldSpaceCameraPos);
        float maxLen = cameraToDepth - cameraToStart;
        float len = 0.f;


        float4 color = float4(_Color.rgb, 0.0);
        float transmittance = 1.0;

        for (int i = 0; i < loop; ++i)
        {
            sample(localPos, _Step, lightStep, color, transmittance);

            len += _Step;
            if (len > maxLen) break;

            localPos += localStep;
        }

        if (len > maxLen)
        {
            float step = maxLen - (len - _Step);
            localPos += step * localDir;
            sample(localPos, step, lightStep, color, transmittance);
        }

        return color;
    }
    ENDCG

    SubShader
    {
        Tags {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        
        Pass
        {
            Cull Back
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Lighting Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            ENDCG
        }
    }
}
