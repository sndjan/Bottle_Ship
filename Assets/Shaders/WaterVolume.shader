Shader "Custom/WaterVolumeClip"
{
    Properties
    {
        _MainTex      ("Water Texture", 2D) = "white" {}
        _Tint         ("Tint", Color) = (0.2, 0.6, 0.7, 0.55)

        _Tiling       ("Tiling (XY)", Vector) = (1, 1, 0, 0)
        _ScrollSpeed  ("Scroll Speed (XY)", Vector) = (0.05, 0.02, 0, 0)

        _FresnelColor ("Fresnel Color", Color) = (1, 1, 1, 1)
        _FresnelPower ("Fresnel Power", Float) = 4.0
        _FresnelStrength ("Fresnel Strength", Range(0,2)) = 0.25

        _Alpha        ("Alpha", Range(0,1)) = 0.55

        // Wasserhöhe in Weltkoordinaten: alles mit worldPos.y > _WaterLevel wird weggeschnitten
        _WaterLevel   ("Water Level (World Y)", Float) = 0.0

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
            float4 _Tint;

            float4 _Tiling;
            float4 _ScrollSpeed;

            float4 _FresnelColor;
            float  _FresnelPower;
            float  _FresnelStrength;

            float  _Alpha;
            float  _WaterLevel;

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
                VertexOutput o;
                o.positionCS = UnityObjectToClipPos(input.positionOS);
                o.worldPos   = mul(unity_ObjectToWorld, input.positionOS).xyz;
                o.normalWS   = UnityObjectToWorldNormal(input.normalOS);
                o.uv         = input.uv * _Tiling.xy;
                return o;
            }

            float4 Frag (VertexOutput i) : SV_Target
            {
                // --- 1) CLIP: alles oberhalb des Wasserlevels wegwerfen ---
                // clip(x) verwirft Pixel wenn x < 0.
                // Wir behalten Pixel nur wenn i.worldPos.y <= _WaterLevel.
                clip(_WaterLevel - i.worldPos.y);

                // --- 2) normales "simple water" shading ---
                float3 N = normalize(i.normalWS);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                float2 uv = i.uv + _ScrollSpeed.xy * _Time.y;
                float4 tex = tex2D(_MainTex, uv);

                float NdotV = saturate(dot(N, V));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                float3 baseCol = tex.rgb * _Tint.rgb;
                float3 edgeCol = _FresnelColor.rgb * (fresnel * _FresnelStrength);

                float3 col = baseCol + edgeCol;

                float alpha = saturate(_Tint.a * _Alpha + fresnel * 0.10);
                return float4(col, alpha);
            }
            ENDCG
        }
    }
}
