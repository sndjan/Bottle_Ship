// Water surface shader
// Animates waves using 4 layered sine waves with different directions and frequencies.
// Two-pass approach: a depth prepass (writes depth, no color) and a color pass (ZTest Equal).
// This avoids transparent sorting issues while still allowing alpha blending.
// Foam around objects in the water is done by comparing scene depth vs water depth
// (same idea as soft particles). The wave functions are also mirrored in WaterBob.cs
// so C# objects (boat, barrels) can float on the surface.

Shader "Custom/WaterCube_FrontOnly" {
    Properties {
        _BaseColor ("Base Color", Color) = (0.06, 0.22, 0.30, 0.88)

        // Waves (match your plane shader)
        _WaveAmp ("Wave Amplitude", Float) = 0.225
        _WaveFreq ("Wave Frequency", Float) = 1.9
        _WaveSpeed ("Wave Speed", Float) = 3.5
        _Choppy ("Choppiness (normal strength)", Float) = 1.0
        _WaveSeed ("Wave Seed", Float) = 3.7

        // Specular / Fresnel
        _Shininess ("Shininess", Float) = 90
        _FresnelPower ("Fresnel Power", Float) = 4.0
        _SpecStrength ("Spec Strength", Float) = 0.2

        // Opacity (nearly opaque, but adjustable)
        _Opacity ("Opacity", Range(0,1)) = 1.0

        // Hard cutoff plane (world-space Y). Anything below is discarded.
        _CutoffY ("Cutoff Height (World Y)", Float) = 7

        // -------- FOAM (around intersecting objects) --------
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamWidth ("Foam Width (Depth)", Float) = 0.2
        _FoamPower ("Foam Power", Float) = 1.0
        _FoamStrength ("Foam Strength", Range(0,2)) = 1.0
        _FoamNoiseScale ("Foam Noise Scale", Float) = 1.0
        _FoamNoiseSpeed ("Foam Noise Speed", Float) = 1.0
        _FoamAlphaBoost ("Foam Alpha Boost", Range(0,1)) = 0.5
    }

    SubShader {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }

        // ---------- PASS 0: Depth prepass (front faces only) ----------
        Pass {
            Tags { "LightMode"="Always" }
            ZWrite On
            ZTest LEqual
            Cull Back
            ColorMask 0

            CGPROGRAM
            #pragma vertex VertDepth
            #pragma fragment FragDepth
            #include "UnityCG.cginc"

            struct VertexInput {
                float4 positionOS : POSITION;
            };

            struct VertexOutput {
                float4 positionCS : SV_POSITION;
                float  worldY     : TEXCOORD0;   // for cutoff
            };

            float _WaveAmp, _WaveFreq, _WaveSpeed, _WaveSeed;
            float _CutoffY;

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

            VertexOutput VertDepth (VertexInput input) {
                VertexOutput o;

                float t = _Time.y;
                float3 worldPos = mul(unity_ObjectToWorld, input.positionOS).xyz;

                worldPos.y += WaveHeight(worldPos.xz, t);

                o.worldY = worldPos.y;
                o.positionCS = UnityWorldToClipPos(worldPos);
                return o;
            }

            float4 FragDepth(VertexOutput i) : SV_Target {
                clip(i.worldY - _CutoffY);
                return 0;
            }
            ENDCG
        }

        // ---------- PASS 1: Color pass (only where depth == closest) ----------
        Pass {
            Tags { "LightMode"="ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Equal
            Cull Back

            CGPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "UnityCG.cginc"

            // Depth texture for foam depth comparison
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

            struct VertexInput {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct VertexOutput {
                float4 positionCS : SV_POSITION;
                float3 worldPos   : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float  worldY     : TEXCOORD2;
                float4 screenPos  : TEXCOORD3;  // for depth-compare foam
            };

            float4 _BaseColor;

            float _WaveAmp, _WaveFreq, _WaveSpeed, _Choppy, _WaveSeed;

            float _Shininess;
            float _FresnelPower;
            float _SpecStrength;

            float _Opacity;
            float _CutoffY;

            float4 _FoamColor;
            float _FoamWidth;
            float _FoamPower;
            float _FoamStrength;
            float _FoamNoiseScale;
            float _FoamNoiseSpeed;
            float _FoamAlphaBoost;

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

            VertexOutput Vert (VertexInput input) {
                VertexOutput o;

                float t = _Time.y;
                float3 worldPos = mul(unity_ObjectToWorld, input.positionOS).xyz;

                worldPos.y += WaveHeight(worldPos.xz, t);

                o.worldPos = worldPos;
                o.worldY = worldPos.y;

                float4 posCS = UnityWorldToClipPos(worldPos);
                o.positionCS = posCS;
                o.screenPos = ComputeScreenPos(posCS);

                float3 geomN = normalize(UnityObjectToWorldNormal(input.normalOS));
                float3 waveN = WaveNormalWS(worldPos, t);

                float topness = saturate(abs(dot(geomN, float3(0,1,0))));
                o.normalWS = normalize(lerp(geomN, waveN, topness));

                return o;
            }

            float FoamNoise(float2 xz, float t) {
                // cheap moving noise: hash-based + sine wobble
                float2 p = xz * _FoamNoiseScale;
                float n = Hash21(p + t * _FoamNoiseSpeed);
                n = n * 0.6 + 0.4 * sin((p.x + p.y) * 1.7 + t * 1.2) * 0.5 + 0.5;
                return saturate(n);
            }

            float4 Frag (VertexOutput i) : SV_Target {
                // Hard cutoff for a clean bottom edge
                clip(i.worldY - _CutoffY);

                float3 N = normalize(i.normalWS);
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                float lambert = max(0.0, dot(N, L));
                float3 R = reflect(-L, N);
                float spec = pow(max(0.0, dot(R, V)), _Shininess) * _SpecStrength;
                float fresnel = pow(1.0 - max(0.0, dot(N, V)), _FresnelPower);

                float3 rgb = _BaseColor.rgb * (0.35 + 0.65 * lambert);
                rgb += spec;
                rgb += fresnel * 0.20;

                float alpha = saturate(_Opacity * _BaseColor.a);

                // -------- FOAM (depth-based intersection foam) --------
                // Compare the scene depth behind the water with the water surface depth.
                // Small difference = geometry close to water surface = foam.
                float2 uv = (i.screenPos.xy / i.screenPos.w);

                // Raw depth from texture -> linear eye depth
                float sceneRaw = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
                float sceneEye = LinearEyeDepth(sceneRaw);

                // Water surface eye depth at this pixel
                float waterEye = LinearEyeDepth(i.screenPos.z / i.screenPos.w);

                // If there is geometry BEHIND the water surface, sceneEye > waterEye.
                // Small positive difference => intersection region => foam.
                float diff = sceneEye - waterEye;

                // Avoid foam when water is behind the opaque surface (object in front of water),
                // or when there is no meaningful depth behind.
                float foamMask = step(0.0001, diff);

                float w = max(_FoamWidth, 1e-4);
                float edge = saturate(1.0 - (diff / w));      // 1 at contact, 0 when farther than width
                edge = pow(edge, _FoamPower) * _FoamStrength;

                float n = FoamNoise(i.worldPos.xz, _Time.y);
                float foam = edge * n * foamMask;

                // Apply foam: brighten towards foam color and slightly increase alpha at foam
                rgb = lerp(rgb, _FoamColor.rgb, saturate(foam));
                alpha = saturate(alpha + foam * _FoamAlphaBoost);

                return float4(rgb, alpha);
            }
            ENDCG
        }
    }
}
