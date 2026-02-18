// Glass shader for the bottle surface
// Uses Fresnel + Blinn-Phong specular to fake glass transparency.
// Fresnel makes the edges more opaque (like real glass), center stays mostly see-through.
// Based on the Fresnel and transparency concepts from Exercise 2 and 3.

Shader "Custom/Glass" {
    Properties {
        _BaseColor      ("Base Color (Tint)", Color) = (0.357, 0.247, 0.020, 0.08)
        _FresnelColor   ("Fresnel Color", Color)     = (1.0, 1.0, 1.0, 1.0)
        _FresnelPower   ("Fresnel Power", Float)     = 6.0
        _SpecPower      ("Specular Power", Float)    = 100.0
        _SpecIntensity  ("Spec Intensity", Float)    = 0.15
        _Alpha          ("Base Alpha", Range(0,1))   = 0.8
    }

    SubShader {
        // Transparent queue - draws after all opaque geometry (same idea as Exercise 3)
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }

        Pass {
            // No depth write + alpha blending for transparency
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "UnityCG.cginc"

            struct VertexInput {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct VertexOutput {
                float4 positionCS : SV_POSITION;
                float3 normalWS   : TEXCOORD0;
                float3 worldPos   : TEXCOORD1;
            };

            float4 _BaseColor;
            float4 _FresnelColor;
            float  _FresnelPower;
            float  _SpecPower;
            float  _SpecIntensity;
            float  _Alpha;

            VertexOutput Vert (VertexInput input) {
                VertexOutput output;

                // Standard transformations (same as in the exercises)
                output.positionCS = UnityObjectToClipPos(input.positionOS);
                output.worldPos = mul(unity_ObjectToWorld, input.positionOS).xyz;
                output.normalWS = UnityObjectToWorldNormal(input.normalOS);

                return output;
            }

            float4 Frag (VertexOutput input) : SV_Target {
                float3 N = normalize(input.normalWS);

                // Light & view direction (same setup as Exercise 2)
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - input.worldPos);

                // Fresnel: edges glow more at flat viewing angles
                // f = (1 - dot(N,V))^power
                float NdotV = saturate(dot(N, V));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                // Minimal diffuse - glass shouldn't be very diffuse, but a bit helps readability
                float NdotL = saturate(dot(N, L));
                float diffuse = max(0.05, NdotL);

                // Blinn-Phong specular (half-vector approach)
                float3 H = normalize(L + V);
                float spec = pow(saturate(dot(N, H)), _SpecPower) * _SpecIntensity;

                // Combine: base tint + fresnel glow + specular
                float3 baseTint = _BaseColor.rgb * diffuse;
                float3 edgeTint = _FresnelColor.rgb * fresnel;

                float3 color = baseTint + edgeTint + spec;

                // Alpha: base alpha + extra opacity at edges from fresnel
                // Makes the glass edges more visible, which looks more realistic
                float alpha = saturate(_Alpha + fresnel * (1.0 - _Alpha));

                return float4(color, alpha);
            }
            ENDCG
        }
    }
}
