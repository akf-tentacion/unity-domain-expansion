//https://light11.hatenadiary.com/entry/2018/12/13/221902

Shader "GrabPassDistortion" 
{
    Properties 
    {
        _DistortionTex ("Distortion Texture(RG)", 2D)            = "white" {}
        _DistortionPower ("Distortion Power", Range(0, 1))     = 0
    }
    
    SubShader 
    {
        Tags {"Queue"="Transparent" "RenderType"="Transparent" }
        
        Cull Back 
        ZWrite On
        ZTest LEqual
        ColorMask RGB

        Pass {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            struct appdata {
                half4 vertex                : POSITION;
                half4 texcoord              : TEXCOORD0;
            };
                
            struct v2f {
                half4 vertex                : SV_POSITION;
                half2 uv                    : TEXCOORD0;
                half4 grabPos               : TEXCOORD1;
            };
            
            sampler2D _DistortionTex;
            half4 _DistortionTex_ST;
            sampler2D  _CameraOpaqueTexture;
            half _DistortionPower;

            v2f vert (appdata v)
            {
                v2f o                   = (v2f)0;
                
                o.vertex                = UnityObjectToClipPos(v.vertex);
                o.uv                    = TRANSFORM_TEX(v.texcoord, _DistortionTex);
                o.grabPos               = ComputeGrabScreenPos(o.vertex);

                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // w除算
                half2 uv            = half2(i.grabPos.x / i.grabPos.w, i.grabPos.y / i.grabPos.w);

                // Distortionの値に応じてサンプリングするUVをずらす
                // 0.5019607 = 128/255 = グレーテクスチャの値
                // 厳密な中間値0.5は8bitで表現できないため微妙にずれる(https://enpedia.rxy.jp/wiki/%E5%8F%8D%E8%BB%A2%E8%89%B2)
                // そのためこれを0.5にしてしまうと_DistortionTex未セットの状態で微妙に歪んでしまう
                float2 distortion   = tex2D(_DistortionTex, i.uv).rg - 0.5019607;
                distortion          *= _DistortionPower;

                uv                  = uv + distortion;
                return tex2D( _CameraOpaqueTexture, uv);
            }
            ENDCG
        }
    }
}