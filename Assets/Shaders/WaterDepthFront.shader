Shader "Hidden/WaterDepthFront"
{
    SubShader
    {
        Tags { "Queue"="Transparent" }
        Pass
        {
            ZWrite Off
            ZTest LEqual
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; };
            struct v2f {
                float4 pos : SV_POSITION;
                float  eyeDepth : TEXCOORD0; // in world units (approx: meters)
            };

            v2f vert(appdata v)
            {
                v2f o;
                float4 viewPos = mul(UNITY_MATRIX_MV, v.vertex);
                o.eyeDepth = -viewPos.z; // positive distance in front of camera
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float frag(v2f i) : SV_Target
            {
                return i.eyeDepth;
            }
            ENDCG
        }
    }
}
