Shader "Custom/WaterSurface_Gerstner"
{
    Properties
    {
        _MainTex ("Water Texture", 2D) = "white" {}
        _Tint    ("Tint", Color) = (0.2, 0.6, 0.7, 0.35)

        _Tiling      ("Tiling (XY)", Vector) = (4, 4, 0, 0)
        _ScrollSpeed ("Scroll Speed (XY)", Vector) = (0.03, 0.02, 0, 0)

        // Gerstner wave params (2 waves)
        _Amp1   ("Amp 1", Float) = 0.02
        _Len1   ("Wavelength 1", Float) = 0.25
        _Speed1 ("Speed 1", Float) = 1.0
        _Dir1   ("Dir 1 (XY)", Vector) = (1, 0, 0, 0)
        _Steep1 ("Steepness 1", Range(0,1)) = 0.35

        _Amp2   ("Amp 2", Float) = 0.012
        _Len2   ("Wavelength 2", Float) = 0.15
        _Speed2 ("Speed 2", Float) = 1.35
        _Dir2   ("Dir 2 (XY)", Vector) = (0.4, 0.9, 0, 0)
        _Steep2 ("Steepness 2", Range(0,1)) = 0.25

        // Edge Fade
        _EdgeFade ("Edge Fade Distance", Range(0,1)) = 0.2

        // Fresnel
        _FresnelColor    ("Fresnel Color", Color) = (1,1,1,1)
        _FresnelPower    ("Fresnel Power", Float) = 4.0
        _FresnelStrength ("Fresnel Strength", Range(0,2)) = 0.8

        _Alpha ("Alpha", Range(0,1)) = 0.35
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

            float _Amp1, _Len1, _Speed1, _Steep1;
            float4 _Dir1;

            float _Amp2, _Len2, _Speed2, _Steep2;
            float4 _Dir2;

            float4 _FresnelColor;
            float  _FresnelPower;
            float  _FresnelStrength;
            float  _Alpha;
            float  _EdgeFade;

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

            // Gerstner helper: returns displacement and a normal contribution in object space (approx)
            void Gerstner(float2 xz, float amp, float wavelength, float speed, float2 dir, float steepness,
                         out float3 dispOS, out float3 nOS)
            {
                dir = normalize(dir);

                // k = 2*pi / wavelength
                float k = 6.2831853 / max(0.0001, wavelength);

                float t = _Time.y * speed;
                float f = k * dot(dir, xz) + t;

                float s = sin(f);
                float c = cos(f);

                // Lateral shift factor q (steepness)
                float q = steepness;

                dispOS = float3(
                    q * amp * dir.x * c,
                    amp * s,
                    q * amp * dir.y * c
                );

                // Approx normal from partial derivatives idea (good enough for simple lighting)
                // Start from (0,1,0) and add slope terms
                nOS = float3(
                    -dir.x * q * k * amp * s,
                    1.0 - q * k * amp * c * 0.0, // keep ~1 (we normalize later)
                    -dir.y * q * k * amp * s
                );
            }

            VertexOutput Vert(VertexInput v)
            {
                VertexOutput o;

                // Use object-space xz plane for waves (works even if object is rotated in world)
                float2 xz = v.positionOS.xz;

                // Calculate edge fade factor (0 at edges, 1 at center)
                float2 uvCentered = v.uv * 2.0 - 1.0;  // Range [-1, 1]
                float distFromCenter = length(uvCentered);
                float fadeStart = 1.0 - _EdgeFade;
                float edgeFade = 1.0 - smoothstep(fadeStart, 1.0, distFromCenter);

                float3 d1, n1;
                Gerstner(xz, _Amp1, _Len1, _Speed1, _Dir1.xy, _Steep1, d1, n1);

                float3 d2, n2;
                Gerstner(xz, _Amp2, _Len2, _Speed2, _Dir2.xy, _Steep2, d2, n2);

                // Apply edge fade to wave displacement
                float3 posOS = v.positionOS.xyz + (d1 + d2) * edgeFade;

                float4 posOS4 = float4(posOS, 1);
                o.positionCS = UnityObjectToClipPos(posOS4);
                o.worldPos   = mul(unity_ObjectToWorld, posOS4).xyz;

                // Combine normals (approx), then transform to world
                float3 nOS = normalize(n1 + n2);
                o.normalWS = UnityObjectToWorldNormal(nOS);

                o.uv = v.uv * _Tiling.xy;
                return o;
            }

            float4 Frag(VertexOutput i) : SV_Target
            {
                float3 N = normalize(i.normalWS);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                float2 uv = i.uv + _ScrollSpeed.xy * _Time.y;
                float4 tex = tex2D(_MainTex, uv);

                float NdotV = saturate(dot(N, V));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                float3 col = tex.rgb * _Tint.rgb
                           + _FresnelColor.rgb * (fresnel * _FresnelStrength);

                float alpha = saturate(_Tint.a * _Alpha + fresnel * 0.12);
                return float4(col, alpha);
            }
            ENDCG
        }
    }
}
