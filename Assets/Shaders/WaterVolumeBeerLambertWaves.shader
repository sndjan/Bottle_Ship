Shader "Custom/WaterVolumeBeerLambertWaves"
{
    Properties
    {
        _ShallowColor ("Shallow Color", Color) = (0.2,0.7,0.8,0.25)
        _DeepColor    ("Deep Color",    Color) = (0.0,0.1,0.2,0.85)
        _Density      ("Absorption Density", Float) = 1.5
        _AlphaScale   ("Alpha Thickness Scale", Float) = 0.5

        _WaveAmp ("Wave Amplitude", Float) = 0.01
        _WaveFreq ("Wave Frequency", Float) = 6.0
        _WaveSpeed("Wave Speed", Float) = 1.0
        _WaveDirA ("Wave Dir A (xz)", Vector) = (1,0,0,0)
        _WaveDirB ("Wave Dir B (xz)", Vector) = (0,0,1,0)
        _WaveTopMaskHeight ("Top Mask Height", Float) = 0.05
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _WaterFrontDepthTex;
            sampler2D _WaterBackDepthTex;

            float4 _ShallowColor, _DeepColor;
            float _Density, _AlphaScale;

            float _WaveAmp, _WaveFreq, _WaveSpeed, _WaveTopMaskHeight;
            float4 _WaveDirA, _WaveDirB;

            float WaveHeight(float2 xz, float t)
            {
                float2 dA = normalize(_WaveDirA.xz);
                float2 dB = normalize(_WaveDirB.xz);

                float w =
                    sin(dot(xz, dA) * _WaveFreq + t) +
                    sin(dot(xz, dB) * (_WaveFreq * 1.37) + t * 1.2);

                return w * _WaveAmp;
            }

            float TopMask_ObjectY(float yObj)
            {
                return saturate(1.0 - (-yObj / max(1e-5, _WaveTopMaskHeight)));
            }

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;

                float t = _Time.y * _WaveSpeed;
                float2 xz = v.vertex.xz;
                float mask = TopMask_ObjectY(v.vertex.y);
                v.vertex.y += WaveHeight(xz, t) * mask;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.screenPos.xy / i.screenPos.w;

                float front = tex2D(_WaterFrontDepthTex, uv).r;
                float back  = tex2D(_WaterBackDepthTex,  uv).r;

                float thickness = max(0.0, back - front);

                float trans = exp(-_Density * thickness);
                float absorb = 1.0 - trans;

                float4 col = lerp(_ShallowColor, _DeepColor, saturate(absorb));

                // weniger transparent nach innen/hinten:
                float alphaBoost = saturate(thickness * _AlphaScale);
                col.a = lerp(_ShallowColor.a, 1.0, alphaBoost);

                return col;
            }
            ENDCG
        }
    }
}
