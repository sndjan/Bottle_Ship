// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/WaterDepthBackWaves"
{
    Properties
    {
        _WaveAmp ("Wave Amplitude", Float) = 0.01
        _WaveFreq ("Wave Frequency", Float) = 6.0
        _WaveSpeed("Wave Speed", Float) = 1.0
        _WaveDirA ("Wave Dir A (xz)", Vector) = (1,0,0,0)
        _WaveDirB ("Wave Dir B (xz)", Vector) = (0,0,1,0)
        _WaveTopMaskHeight ("Top Mask Height", Float) = 0.05
    }

    SubShader
    {
        Tags { "Queue"="Transparent" }
        Pass
        {
            ZWrite Off
            ZTest LEqual
            Cull Front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

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

            struct appdata { float4 vertex : POSITION; };
            struct v2f { float4 pos : SV_POSITION; float eyeDepth : TEXCOORD0; };

            v2f vert(appdata v)
            {
                v2f o;
                float t = _Time.y * _WaveSpeed;
                float2 xz = v.vertex.xz;
                float mask = TopMask_ObjectY(v.vertex.y);
                v.vertex.y += WaveHeight(xz, t) * mask;

                float4 viewPos = mul(UNITY_MATRIX_MV, v.vertex);
                o.eyeDepth = -viewPos.z;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float frag(v2f i) : SV_Target { return i.eyeDepth; }
            ENDCG
        }
    }
}
