Shader "Custom/Water"
{
    Properties
    {
        _MainTex        ("Water Texture", 2D) = "white" {}
        _Tint           ("Tint", Color) = (0.2, 0.6, 0.7, 0.35)

        _Tiling         ("Tiling (XY)", Vector) = (1, 1, 0, 0)
        _ScrollSpeed    ("Scroll Speed (XY)", Vector) = (0.05, 0.02, 0, 0)

        _FresnelColor   ("Fresnel Color", Color) = (1, 1, 1, 1)
        _FresnelPower   ("Fresnel Power", Float) = 4.0
        _FresnelStrength("Fresnel Strength", Range(0,2)) = 0.5

        _Alpha          ("Alpha", Range(0,1)) = 0.35

        // Praktisch, damit Surface nicht "verschwindet":
        // 0=Off, 1=Front, 2=Back (Unity Cull enums)
        [Enum(Off,0, Front,1, Back,2)] _Cull ("Cull Mode", Float) = 0
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }

        Pass
        {
            Cull [_Cull]
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _Tint;

            float4 _Tiling;
            float4 _ScrollSpeed;

            float4 _FresnelColor;
            float  _FresnelPower;
            float  _FresnelStrength;

            float  _Alpha;

            struct VertexInput
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct VertexOutput
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 worldPos   : TEXCOORD2;
            };

            VertexOutput Vert (VertexInput input)
            {
                VertexOutput output;
                output.positionCS = UnityObjectToClipPos(input.positionOS);

                output.worldPos = mul(unity_ObjectToWorld, input.positionOS).xyz;
                output.normalWS = UnityObjectToWorldNormal(input.normalOS);

                // UV: tiling + ggf. Unity ST (falls du im Material Tiling/Offset nutzt)
                output.uv = input.uv * _Tiling.xy;

                return output;
            }

            float4 Frag (VertexOutput input) : SV_Target
            {
                float3 N = normalize(input.normalWS);
                float3 V = normalize(_WorldSpaceCameraPos - input.worldPos);

                // UV Scroll (einfach, "exercise-like")
                float2 uv = input.uv;
                uv += _ScrollSpeed.xy * _Time.y;

                // Texture sample
                float4 tex = tex2D(_MainTex, uv);

                // Fresnel: Kanten hell, Mitte weniger
                float NdotV = saturate(dot(N, V));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                // Farbe: Texture * Tint + Fresnel-Highlight
                float3 baseCol = tex.rgb * _Tint.rgb;
                float3 edgeCol = _FresnelColor.rgb * (fresnel * _FresnelStrength);

                float3 col = baseCol + edgeCol;

                // Alpha: TintAlpha * _Alpha + bisschen mehr an Kanten
                float alpha = saturate((_Tint.a * _Alpha) + fresnel * 0.15);

                return float4(col, alpha);
            }
            ENDCG
        }
    }
}
