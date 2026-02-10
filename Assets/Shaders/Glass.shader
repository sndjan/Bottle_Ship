Shader "Custom/GlassFresnel" {
    Properties {
        _BaseColor      ("Base Color (Tint)", Color) = (0.8, 0.95, 1.0, 0.08)
        _FresnelColor   ("Fresnel Color", Color)     = (1.0, 1.0, 1.0, 1.0)
        _FresnelPower   ("Fresnel Power", Float)     = 5.0
        _SpecPower      ("Specular Power", Float)    = 64.0
        _SpecIntensity  ("Spec Intensity", Float)    = 1.0
        _Alpha          ("Base Alpha", Range(0,1))   = 0.08
    }

    SubShader {
        // Transparent Queue wie im Transparency-Exercise
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }  // :contentReference[oaicite:4]{index=4}

        Pass {
            // Für klassische Transparenz: kein Depth Write + Alpha Blending
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha  // :contentReference[oaicite:5]{index=5}

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

                // Object -> Clip (wie in den Exercises)
                output.positionCS = UnityObjectToClipPos(input.positionOS);  // :contentReference[oaicite:6]{index=6}

                // WorldPos & WorldNormal (wie in Exercise 2)
                output.worldPos = mul(unity_ObjectToWorld, input.positionOS).xyz; // :contentReference[oaicite:7]{index=7}
                output.normalWS = UnityObjectToWorldNormal(input.normalOS);       // :contentReference[oaicite:8]{index=8}

                return output;
            }

            float4 Frag (VertexOutput input) : SV_Target {
                float3 N = normalize(input.normalWS);

                // Unity Built-ins: Light & Camera (wie bei euren Lighting-Shaders)
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - input.worldPos);

                // 1) Fresnel: stark bei flachem Winkel (Kante)
                // f = (1 - dot(N,V))^power
                float NdotV = saturate(dot(N, V));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                // 2) Minimal-Diffuse (Glas ist eher wenig diffus, aber für "Lesbarkeit" etwas Licht)
                float NdotL = saturate(dot(N, L));
                float diffuse = max(0.05, NdotL);

                // 3) Simple Specular (Blinn-Phong)
                float3 H = normalize(L + V);
                float spec = pow(saturate(dot(N, H)), _SpecPower) * _SpecIntensity;

                // 4) Farbe: BaseTint + Fresnel-Glanz + Spec
                float3 baseTint = _BaseColor.rgb * diffuse;
                float3 edgeTint = _FresnelColor.rgb * fresnel;

                float3 color = baseTint + edgeTint + spec;

                // 5) Alpha: Grund-Alpha + (optional) mehr Opazität an Kanten durch Fresnel
                // -> wirkt "glasiger", weil Kanten stärker sichtbar sind
                float alpha = saturate(_Alpha + fresnel * (1.0 - _Alpha));

                return float4(color, alpha);
            }
            ENDCG
        }
    }
}
