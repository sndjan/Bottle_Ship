Shader "Custom/WaterVolumeBeerLambert"
{
    Properties
    {
        _ShallowColor ("Shallow Color", Color) = (0.2, 0.7, 0.8, 0.25)
        _DeepColor    ("Deep Color",    Color) = (0.0, 0.1, 0.2, 0.85)
        _Density      ("Absorption Density", Float) = 1.5
        _AlphaScale ("Alpha Thickness Scale", Float) = 0.5

    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _WaterFrontDepthTex;
            sampler2D _WaterBackDepthTex;

            float4 _ShallowColor;
            float4 _DeepColor;
            float _Density;
            float _AlphaScale;

            struct appdata { float4 vertex : POSITION; };
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.screenPos.xy / i.screenPos.w;

                float front = tex2D(_WaterFrontDepthTex, uv).r;
                float back  = tex2D(_WaterBackDepthTex,  uv).r;

                float thickness = max(0.0, back - front);

                float trans = exp(-_Density * thickness);
                float absorb = 1.0 - trans;

                // Farbe wird tiefer dunkler
                float4 col = lerp(_ShallowColor, _DeepColor, absorb);

                // Transparenz nimmt mit Dicke ab
                float alphaBoost = saturate(thickness * _AlphaScale);
                col.a = lerp(_ShallowColor.a, 1.0, alphaBoost);

                return col;

            }
            ENDCG
        }
    }
}
