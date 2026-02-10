using UnityEngine;

public class BoatFoamDriver : MonoBehaviour {
    [Header("Assign BOTH water renderers (top & sides if desired)")]
    public Renderer[] waterRenderers;

    public float foamRadius = 1.2f;
    public float foamWidth = 0.5f;

    static readonly int BoatPosID = Shader.PropertyToID("_BoatPos");
    static readonly int BoatRadiusID = Shader.PropertyToID("_BoatRadius");
    static readonly int BoatWidthID = Shader.PropertyToID("_BoatFoamWidth");

    MaterialPropertyBlock _mpb;

    void Awake() {
        _mpb = new MaterialPropertyBlock();
    }

    void LateUpdate() {
        Vector3 p = transform.position;

        foreach (var r in waterRenderers) {
            if (!r) continue;
            r.GetPropertyBlock(_mpb);
            _mpb.SetVector(BoatPosID, new Vector4(p.x, p.y, p.z, 1));
            _mpb.SetFloat(BoatRadiusID, foamRadius);
            _mpb.SetFloat(BoatWidthID, foamWidth);
            r.SetPropertyBlock(_mpb);
        }
    }
}
