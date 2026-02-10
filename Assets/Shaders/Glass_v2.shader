Shader "Custom/Exercise/GlassTransparent"
{
    Properties
    {
        _BaseColor ("Tint Color", Color) = (1,1,1,1)

        _BaseMap   ("Base Color (RGB)", 2D) = "white" {}
        _OpacityMap("Opacity (R)", 2D) = "white" {}

        _NormalMap ("Normal (OpenGL)", 2D) = "bump" {}
        _MetallicMap("Metallic (R)", 2D) = "black" {}
        _RoughnessMap("Roughness (R)", 2D) = "white" {}
        _AOMap     ("AO (R)", 2D) = "white" {}

        _NormalStrength ("Normal Strength", Range(0,2)) = 1
        _SpecStrength   ("Spec Strength", Range(0,2)) = 1
        _FresnelPower   ("Fresnel Power", Range(0.5,8)) = 4

        _EnvStrength ("Fake Env Strength", Range(0,2)) = 0.6
        _AlphaMultiplier ("Alpha Multiplier", Range(0,2)) = 1
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        LOD 200

        // Classic alpha blending
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            sampler2D _BaseMap;
            sampler2D _OpacityMap;
            sampler2D _NormalMap;
            sampler2D _MetallicMap;
            sampler2D _RoughnessMap;
            sampler2D _AOMap;

            float4 _BaseMap_ST;
            float4 _BaseColor;

            float _NormalStrength;
            float _SpecStrength;
            float _FresnelPower;
            float _EnvStrength;
            float _AlphaMultiplier;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent: TANGENT;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos      : SV_POSITION;
                float2 uv       : TEXCOORD0;

                float3 worldPos : TEXCOORD1;
                float3 worldN   : TEXCOORD2;
                float3 worldT   : TEXCOORD3;
                float3 worldB   : TEXCOORD4;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                o.worldN = UnityObjectToWorldNormal(v.normal);
                o.worldT = UnityObjectToWorldDir(v.tangent.xyz);
                // bitangent sign in tangent.w
                o.worldB = cross(o.worldN, o.worldT) * v.tangent.w;

                return o;
            }

            // Simple helper: Fresnel (Schlick-ish, but "exercise simple")
            float FresnelTerm(float3 N, float3 V, float power)
            {
                float ndv = saturate(dot(N, V));
                return pow(1.0 - ndv, power);
            }

            float4 frag(v2f i) : SV_Target
            {
                // Normalize basis
                float3 N = normalize(i.worldN);
                float3 T = normalize(i.worldT);
                float3 B = normalize(i.worldB);

                // Sample textures
                float4 baseTex = tex2D(_BaseMap, i.uv);
                float  opacity = tex2D(_OpacityMap, i.uv).r;

                float  metallic = tex2D(_MetallicMap, i.uv).r;
                float  roughness = tex2D(_RoughnessMap, i.uv).r;
                float  ao = tex2D(_AOMap, i.uv).r;

                // Roughness -> Smoothness
                float smoothness = 1.0 - roughness;

                // Normal map (Unity's UnpackNormal expects DXTnm-ish; for PNG it still works with "Normal map" import)
                float3 nTS = UnpackNormal(tex2D(_NormalMap, i.uv));
                nTS.xy *= _NormalStrength;
                nTS = normalize(nTS);

                // Transform tangent-space normal to world
                float3x3 TBN = float3x3(T, B, N);
                float3 Nw = normalize(mul(TBN, nTS));

                // Lighting vectors
                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

                // Main directional light (ForwardBase)
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightCol = _LightColor0.rgb;

                // Diffuse (Lambert) - for glass keep it subtle
                float ndl = saturate(dot(Nw, L));
                float3 albedo = baseTex.rgb * _BaseColor.rgb;

                // Specular (Blinn-Phong) with smoothness -> shininess mapping
                float3 H = normalize(L + V);
                float ndh = saturate(dot(Nw, H));

                // Map smoothness (0..1) to exponent (approx)
                float shininess = lerp(8.0, 256.0, smoothness);
                float spec = pow(ndh, shininess) * _SpecStrength;

                // Fresnel boosts spec at grazing angles (glass look)
                float fresnel = FresnelTerm(Nw, V, _FresnelPower);

                // Metallic workflow (simple):
                // - Dielectric spec baseline ~0.04
                // - Metals use albedo as spec color and low diffuse
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), albedo, metallic);
                float3 specCol = F0 * (spec + fresnel);

                float3 diffCol = albedo * (1.0 - metallic);

                // "Fake environment" reflection (very cheap, exercise-style)
                // Use fresnel only; no cubemap
                float3 env = albedo * (_EnvStrength * fresnel);

                // Combine, apply AO
                float3 color =
                    (diffCol * ndl + specCol * ndl) * lightCol +
                    env;

                color *= lerp(1.0, ao, 0.8);

                // Transparency from opacity map (R) + base color alpha
                float alpha = saturate(opacity * _BaseColor.a * _AlphaMultiplier);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
