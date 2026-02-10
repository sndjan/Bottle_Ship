Shader "Custom/Water" {
    Properties {
        _BaseColor ("Base Color", Color) = (0.06, 0.22, 0.30, 0.88)

        // Waves (organic / pseudo-random via multi-sine)
        _WaveAmp ("Wave Amplitude", Float) = 0.18
        _WaveFreq ("Wave Frequency", Float) = 1.4
        _WaveSpeed ("Wave Speed", Float) = 1.1
        _Choppy ("Choppiness (normal strength)", Float) = 1.0
        _WaveSeed ("Wave Seed", Float) = 3.7

        // Specular / Fresnel
        _Shininess ("Shininess", Float) = 96
        _FresnelPower ("Fresnel Power", Float) = 4.5
        _SpecStrength ("Spec Strength", Float) = 0.9

        // Foam (color + noise)
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 1)
        _FoamNoise ("Foam Noise (2D)", 2D) = "gray" {}
        _FoamNoiseScale ("Foam Noise Scale", Float) = 4.0
        _FoamNoiseSpeed ("Foam Noise Speed", Float) = 0.45
        _FoamNoiseContrast ("Foam Noise Contrast", Float) = 2.0

        // Intersection foam: hard rim + noisy outer fade
        _FoamRimWidth ("Foam Rim Width", Float) = 0.08
        _FoamRimHardness ("Foam Rim Hardness", Float) = 0.015
        _FoamOuterWidth ("Foam Outer Width", Float) = 0.75
        _FoamOuterSoftness ("Foam Outer Softness", Float) = 0.25
        _FoamIntensity ("Intersection Foam Intensity", Float) = 2.0

        // Crest foam: foam on wave crests (based on steepness)
        _CrestThreshold ("Crest Threshold", Range(0,1)) = 0.35
        _CrestSoftness ("Crest Softness", Range(0.001,0.5)) = 0.12
        _CrestIntensity ("Crest Intensity", Float) = 1.25
        _CrestNoiseInfluence ("Crest Noise Influence", Range(0,1)) = 0.7

        // Less transparent water
        _Opacity ("Opacity", Range(0,1)) = 0.9
    }

    SubShader {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass {
            CGPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "UnityCG.cginc"

            struct VertexInput {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct VertexOutput {
                float4 positionCS : SV_POSITION;
                float3 worldPos   : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
                float4 screenPos  : TEXCOORD3;
            };

            float4 _BaseColor;

            float _WaveAmp;
            float _WaveFreq;
            float _WaveSpeed;
            float _Choppy;
            float _WaveSeed;

            float _Shininess;
            float _FresnelPower;
            float _SpecStrength;

            float4 _FoamColor;

            sampler2D _FoamNoise;
            float4 _FoamNoise_ST;
            float _FoamNoiseScale;
            float _FoamNoiseSpeed;
            float _FoamNoiseContrast;

            float _FoamRimWidth;
            float _FoamRimHardness;
            float _FoamOuterWidth;
            float _FoamOuterSoftness;
            float _FoamIntensity;

            float _CrestThreshold;
            float _CrestSoftness;
            float _CrestIntensity;
            float _CrestNoiseInfluence;

            float _Opacity;

            sampler2D _CameraDepthTexture;

            // --- Helpers -------------------------------------------------------

            float Hash21(float2 p) {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float2 DirFromSeed(float s) {
                float a = frac(s) * 6.2831853;
                return float2(cos(a), sin(a));
            }

            float WaveHeight(float2 xz, float t) {
                float s = _WaveSeed;

                float2 d0 = DirFromSeed(s + 0.11);
                float2 d1 = DirFromSeed(s + 0.37);
                float2 d2 = DirFromSeed(s + 0.73);
                float2 d3 = DirFromSeed(s + 1.19);

                float phaseJitter = (Hash21(xz * 0.15 + s) - 0.5) * 1.2;

                float f0 = _WaveFreq * 1.00;
                float f1 = _WaveFreq * 1.63;
                float f2 = _WaveFreq * 2.31;
                float f3 = _WaveFreq * 3.17;

                float a0 = _WaveAmp * 0.55;
                float a1 = _WaveAmp * 0.25;
                float a2 = _WaveAmp * 0.14;
                float a3 = _WaveAmp * 0.06;

                float h = 0.0;
                h += sin(dot(xz, d0) * f0 + t * (_WaveSpeed * 1.00) + phaseJitter) * a0;
                h += sin(dot(xz, d1) * f1 + t * (_WaveSpeed * 1.27) + phaseJitter * 0.7) * a1;
                h += sin(dot(xz, d2) * f2 + t * (_WaveSpeed * 1.63) + phaseJitter * 0.4) * a2;
                h += sin(dot(xz, d3) * f3 + t * (_WaveSpeed * 2.05) + phaseJitter * 0.2) * a3;

                return h;
            }

            float3 WaveNormalWS(float3 worldPos, float t) {
                float e = 0.06;
                float hC = WaveHeight(worldPos.xz, t);
                float hX = WaveHeight(worldPos.xz + float2(e, 0), t);
                float hZ = WaveHeight(worldPos.xz + float2(0, e), t);

                float3 dX = float3(e, (hX - hC) * _Choppy, 0);
                float3 dZ = float3(0, (hZ - hC) * _Choppy, e);

                return normalize(cross(dZ, dX));
            }

            // --- Vertex --------------------------------------------------------

            VertexOutput Vert (VertexInput input) {
                VertexOutput output;

                float t = _Time.y;
                float3 worldPos = mul(unity_ObjectToWorld, input.positionOS).xyz;

                worldPos.y += WaveHeight(worldPos.xz, t);

                output.worldPos = worldPos;
                output.positionCS = UnityWorldToClipPos(worldPos);
                output.normalWS = WaveNormalWS(worldPos, t);
                output.uv = input.uv;
                output.screenPos = ComputeScreenPos(output.positionCS);

                return output;
            }

            // --- Fragment ------------------------------------------------------

            float4 Frag (VertexOutput input) : SV_Target {
                float3 N = normalize(input.normalWS);
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - input.worldPos);

                // Lighting
                float lambert = max(0.0, dot(N, L));
                float3 R = reflect(-L, N);
                float spec = pow(max(0.0, dot(R, V)), _Shininess) * _SpecStrength;
                float fresnel = pow(1.0 - max(0.0, dot(N, V)), _FresnelPower);

                float3 waterRGB = _BaseColor.rgb * (0.35 + 0.65 * lambert);
                waterRGB += spec;
                waterRGB += fresnel * 0.20;

                // Shared foam noise (world-anchored, animated)
                float2 foamUV = (input.worldPos.xz * _FoamNoiseScale) + (_Time.y * _FoamNoiseSpeed);
                float noise = tex2D(_FoamNoise, foamUV * _FoamNoise_ST.xy + _FoamNoise_ST.zw).r;
                noise = saturate(pow(noise, 1.0 / max(0.001, _FoamNoiseContrast)));

                // --- 1) Intersection foam (object contact) ----------------------
                float2 screenUV = (input.screenPos.xy / input.screenPos.w);
                float sceneEye = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV));
                float waterEye = LinearEyeDepth(input.screenPos.z / input.screenPos.w);
                float depthDiff = sceneEye - waterEye;

                float rim = smoothstep(_FoamRimWidth, _FoamRimWidth - _FoamRimHardness, depthDiff);
                float outer = smoothstep(_FoamOuterWidth, _FoamOuterWidth - _FoamOuterSoftness, depthDiff);

                // Outer eroded by noise, rim stays white
                outer *= smoothstep(0.20, 0.85, noise);

                float foamIntersection = saturate(rim + outer * 0.9);
                foamIntersection = saturate(foamIntersection * _FoamIntensity);

                // --- 2) Crest foam (on wave crests) ------------------------------
                // Steepness proxy: flatter surface -> N.y near 1; steeper -> N.y smaller
                float steepness = saturate(1.0 - N.y);

                // Threshold band: only steep parts become foam
                float crest = smoothstep(_CrestThreshold, _CrestThreshold + _CrestSoftness, steepness);

                // Break up with noise (only partly, so it remains "streaky")
                float crestNoiseMask = lerp(1.0, smoothstep(0.25, 0.85, noise), _CrestNoiseInfluence);
                float foamCrest = saturate(crest * crestNoiseMask * _CrestIntensity);

                // Combine foams
                float foam = saturate(foamIntersection + foamCrest);

                // Composite foam
                waterRGB = lerp(waterRGB, _FoamColor.rgb, foam);

                // Opacity: generally less transparent + foam opaque
                float alpha = saturate(_Opacity * _BaseColor.a + foam * 0.9);

                return float4(waterRGB, alpha);
            }
            ENDCG
        }
    }
}
