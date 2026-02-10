using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class WaterThicknessBuiltin : MonoBehaviour
{
    [Header("Assign these in Inspector")]
    public RenderTexture frontDepthRT;
    public RenderTexture backDepthRT;

    [Header("Water selection")]
    public LayerMask waterLayer;

    [Header("Depth shaders")]
    public Shader frontDepthShader;
    public Shader backDepthShader;

    private Camera cam;
    private CommandBuffer cbFront;
    private CommandBuffer cbBack;
    private Material matFront;
    private Material matBack;

    private readonly List<Renderer> waterRenderers = new();

    void OnEnable()
    {
        cam = GetComponent<Camera>();
        Build();
    }

    void OnDisable()
    {
        Cleanup();
    }

    void OnValidate()
    {
        // Editor: bei Änderungen neu bauen
        if (enabled && gameObject.activeInHierarchy)
        {
            Cleanup();
            Build();
        }
    }

    void Build()
    {
        if (cam == null) cam = GetComponent<Camera>();
        if (frontDepthRT == null || backDepthRT == null) return;
        if (frontDepthShader == null || backDepthShader == null) return;

        matFront = new Material(frontDepthShader);
        matBack  = new Material(backDepthShader);

        CollectWaterRenderers();

        cbFront = new CommandBuffer { name = "Water Front Depth" };
        cbBack  = new CommandBuffer { name = "Water Back Depth" };

        // Front RT
        cbFront.SetRenderTarget(frontDepthRT);
        cbFront.ClearRenderTarget(false, true, Color.black);
        foreach (var r in waterRenderers)
            if (r) cbFront.DrawRenderer(r, matFront);

        // Back RT
        cbBack.SetRenderTarget(backDepthRT);
        cbBack.ClearRenderTarget(false, true, Color.black);
        foreach (var r in waterRenderers)
            if (r) cbBack.DrawRenderer(r, matBack);

        // Timing: vor Transparent-Rendering (Flasche/Wasser sind transparent)
        cam.AddCommandBuffer(CameraEvent.BeforeForwardAlpha, cbFront);
        cam.AddCommandBuffer(CameraEvent.BeforeForwardAlpha, cbBack);

        // Global für Shader verfügbar machen
        Shader.SetGlobalTexture("_WaterFrontDepthTex", frontDepthRT);
        Shader.SetGlobalTexture("_WaterBackDepthTex", backDepthRT);
    }

    void CollectWaterRenderers()
    {
        waterRenderers.Clear();
        var all = FindObjectsOfType<Renderer>(true);
        foreach (var r in all)
        {
            if (((1 << r.gameObject.layer) & waterLayer.value) != 0)
                waterRenderers.Add(r);
        }
    }

    void Cleanup()
    {
        if (cam)
        {
            if (cbFront != null) cam.RemoveCommandBuffer(CameraEvent.BeforeForwardAlpha, cbFront);
            if (cbBack  != null) cam.RemoveCommandBuffer(CameraEvent.BeforeForwardAlpha, cbBack);
        }

        cbFront?.Release(); cbFront = null;
        cbBack?.Release();  cbBack = null;

        if (matFront) DestroyImmediate(matFront);
        if (matBack)  DestroyImmediate(matBack);
    }
}
