Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100

        Pass
        {
            Cull Back
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Lighting Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #include "UnityCG.cginc"
            #include "MyMath.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;


            float hash(float n ){
                return frac(sin(n) * 43758.5453);
            }

            float noise(float3 x){
                float3 p = floor(x);
                float3 f = frac(x);

                f = f * f * (3.0 - 2.0 * f);
                float n = p.x + p.y * 57.0 + 113.0 * p.z;
    
                float res = (lerp(lerp(hash(n +   0.0), hash(n +   1.0), f.x),
                                    lerp(hash(n +  57.0), hash(n +  58.0), f.x), f.y),
                                lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                                    lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
                return res;
            }

            float fbm(float3 p){
                float f;
                f  = 0.5000 * noise(p); p = mul(m,p) * 2.02;
                f += 0.2500 * noise(p); p = mul(m,p) * 2.03;
                f += 0.1250 * noise(p);
                return f;
            }

            float scene(float3 pos){
                return 0.1 - length(pos) * 0.05 + fBm3D(pos.xyz * 0.3);
            }

            float3 getNormal(float3 p){
                const float e = 0.01;
                return normalize(float3(scene(float3(p.x + e, p.y, p.z)) - scene(float3(p.x - e, p.y, p.z)),
                          scene(float3(p.x, p.y + e, p.z)) - scene(float3(p.x, p.y - e, p.z)),
                          scene(float3(p.x, p.y, p.z + e)) - scene(float3(p.x, p.y, p.z - e))));
            }

            float3x3 camera(float3 ro, float3 ta){
                float3 cw = normalize(ta - ro);
                float3 cp = float3(0.0, 1.0, 0.0);
                float3 cu = cross(cw, cp);
                float3 cv = cross(cu, cw);
                return float3x3(cu, cv, cw);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv - float2(0.5,0.5);
                float2 mo = float2(_Time.w * 0.1, cos(_Time.w * 0.25) * 3.0);

                float camDist = 25.;
                float3 ta = float3(0.0,1.0,0.0);


                //float3 ro = float3(sin(_Time.w) * camDist, 0, cos(_Time.w) * camDist);
                //float3 ro = float3(10,-10,-20);
                float3 ro = camDist * normalize(float3(cos(2.75 - 3.0 * mo.x), 0.7 - 1.0 * (mo.y - 1.0), sin(2.75 - 3.0 * mo.x)));

                float targetDepth = 0.4;

                float3x3 c = camera(ro,ta);

                float3 dir = mul(c , normalize(float3(uv,targetDepth)));

                const int sampleCount = 64;
                const int sampleLightCount = 6;
                const float eps = 0.01;

                float zMax = 40.0;
                float zstep = zMax / float(sampleLightCount);
                float zMaxl = 20.0;
                float zstepl = zMaxl / float(sampleLightCount);

                float3 p = ro;

                float T = 1.0;

                float absorption = 100.0;

                float3 sun_direction = normalize(float3(1.0,0.0,0.0));

                float4 color = 0.0;

                for(int i = 0; i < sampleCount ; i++){
                    float density = scene(p);

                    if(density > 0.0){
                        float tmp = density / float(sampleCount);

                        T *= 1.0 - (tmp * absorption);
                        if(T <= 0.01){
                            break;
                        }
                        float Tl = 1.0;

                        float3 lp = p;

                        for(int j = 0; j < sampleLightCount; j++){
                            float densityLight = scene(lp);

                            if(densityLight > 0.0){
                                float tmpl = densityLight / float(sampleCount);
                                Tl *= 1.0 - (tmpl * absorption);

                            }

                            if(Tl <= 0.01){
                                break;

                            }

                            lp *= sun_direction * zstepl;
                        }


                        // Add ambient + light scattering color
                        float opaity = 50.0;
                        float k = opaity * tmp * T;
                        float4 cloudColor = 1.0;
                        float4 col1 = cloudColor * k;
                        
                    
                        float opacityl = 30.0;
                        float kl = opacityl * tmp * T * Tl;
                        float4 lightColor = float4(1.0, 0.7, 0.9, 1.0);
                        float4 col2 = lightColor * kl;
            

                        //float4 col2 = 0.;
                        
                        color += col1 + col2;
                    }

                    p += dir * zstep;

                }

                    
                float3 bg = lerp(float3(0.3, 0.1, 0.8), float3(0.7, 0.7, 1.0), 1.0 - (uv.y + 1.0) * 0.5);

                color.rgb += bg;

                // sample the texture
                fixed4 col = color;
                // apply fog
                return col;
            }
            ENDCG
        }
    }
}
