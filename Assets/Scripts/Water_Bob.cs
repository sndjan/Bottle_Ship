// Makes an object (ship, barrels, etc.) float on the water surface.
// The wave math here is a 1:1 copy of what the Water.shader does on the GPU.
// That way the position always matches exactly.
// Also tilts the object to follow the wave normal for a more natural look.

using UnityEngine;

[DisallowMultipleComponent]
public class Water_Bob : MonoBehaviour {
    [Header("Material (reads wave params from here)")]
    public Material waterMaterial;

    [Header("Wave Params (match shader)")]
    public float waveAmp = 0.18f;
    public float waveFreq = 1.4f;
    public float waveSpeed = 1.1f;
    public float choppy = 1.0f;
    public float waveSeed = 3.7f;

    [Header("Bobbing")]
    public float followHeight = 1.0f;
    public float heightOffset = 0.0f;

    [Header("Tilt")]
    public bool tiltToWave = true;
    [Range(0, 1)] public float tiltStrength = 0.75f;
    public float tiltLerpSpeed = 6.0f;

    [Header("Baseline")]
    public bool recaptureBaselineOnEnable = true;
    public bool allowRecaptureWithR = true;

    [Header("Sampling")]
    public float normalEpsilon = 0.06f;  // finite difference step, same as in shader

    [Header("Update Mode")]
    public bool readMaterialEveryFrame = false;

    // Stores the initial position/rotation so we always sample relative to that
    private Vector3 _basePos;
    private Quaternion _baseRot;

    void OnEnable() {
        if (recaptureBaselineOnEnable)
            CaptureBaseline();
    }

    void Start() {
        if (_baseRot == default)
            CaptureBaseline();

        ReadParamsFromMaterial();
    }

    void Update() {
        if (allowRecaptureWithR && Input.GetKeyDown(KeyCode.R))
            CaptureBaseline();

        if (readMaterialEveryFrame)
            ReadParamsFromMaterial();

        // Time.time is close enough to _Time.y in the shader
        float t = Time.time;

        // Always sample at the baseline XZ, not the current transform
        // (otherwise the object would drift because it keeps moving)
        Vector2 xz = new Vector2(_basePos.x, _basePos.z);
        float h = WaveHeight(xz, t);

        // Move relative to baseline Y so it doesn't accumulate errors
        Vector3 p = _basePos;
        p.y = _basePos.y + (h * followHeight) + heightOffset;
        transform.position = p;

        if (tiltToWave) {
            // Estimate wave normal at our position
            Vector3 n = WaveNormal(new Vector3(_basePos.x, _basePos.y, _basePos.z), t);

            // Rotate our up-vector towards the wave normal
            Quaternion tilt = Quaternion.FromToRotation(_baseRot * Vector3.up, n);
            Quaternion target = Quaternion.Slerp(_baseRot, tilt * _baseRot, tiltStrength);

            // Smooth interpolation so it doesn't snap
            float k = 1f - Mathf.Exp(-tiltLerpSpeed * Time.deltaTime);
            transform.rotation = Quaternion.Slerp(transform.rotation, target, k);
        }
        else {
            transform.rotation = _baseRot;
        }
    }

    void CaptureBaseline() {
        _basePos = transform.position;
        _baseRot = transform.rotation;
        transform.rotation = _baseRot;
    }

    // Read the wave params from the material so they stay in sync with the shader
    void ReadParamsFromMaterial() {
        if (!waterMaterial) return;

        if (waterMaterial.HasProperty("_WaveAmp")) waveAmp = waterMaterial.GetFloat("_WaveAmp");
        if (waterMaterial.HasProperty("_WaveFreq")) waveFreq = waterMaterial.GetFloat("_WaveFreq");
        if (waterMaterial.HasProperty("_WaveSpeed")) waveSpeed = waterMaterial.GetFloat("_WaveSpeed");
        if (waterMaterial.HasProperty("_Choppy")) choppy = waterMaterial.GetFloat("_Choppy");
        if (waterMaterial.HasProperty("_WaveSeed")) waveSeed = waterMaterial.GetFloat("_WaveSeed");
    }

    // -------------------------------------------------------------------------
    // Wave math - exact copy of the shader functions
    // Has to produce the same results, otherwise objects won't sit on the water.
    // -------------------------------------------------------------------------

    static float Frac(float x) => x - Mathf.Floor(x);

    // Simple hash for pseudo-random phase jitter (same as in shader)
    static float Hash21(Vector2 p)
    {
        p = new Vector2(Frac(p.x * 123.34f), Frac(p.y * 456.21f));
        float d = Vector2.Dot(p, p + new Vector2(45.32f, 45.32f));
        p += new Vector2(d, d);
        return Frac(p.x * p.y);
    }

    // Turns a seed into a 2D direction (for wave travel direction)
    static Vector2 DirFromSeed(float s)
    {
        float a = Frac(s) * (Mathf.PI * 2f);
        return new Vector2(Mathf.Cos(a), Mathf.Sin(a));
    }

    // Sum of 4 sine waves - same formula as WaveHeight() in Water.shader
    float WaveHeight(Vector2 xz, float t)
    {
        float s = waveSeed;

        Vector2 d0 = DirFromSeed(s + 0.11f);
        Vector2 d1 = DirFromSeed(s + 0.37f);
        Vector2 d2 = DirFromSeed(s + 0.73f);
        Vector2 d3 = DirFromSeed(s + 1.19f);

        float phaseJitter = (Hash21(xz * 0.15f + new Vector2(s, s)) - 0.5f) * 1.2f;

        float f0 = waveFreq * 1.00f;
        float f1 = waveFreq * 1.63f;
        float f2 = waveFreq * 2.31f;
        float f3 = waveFreq * 3.17f;

        float a0 = waveAmp * 0.55f;
        float a1 = waveAmp * 0.25f;
        float a2 = waveAmp * 0.14f;
        float a3 = waveAmp * 0.06f;

        float h = 0f;
        h += Mathf.Sin(Vector2.Dot(xz, d0) * f0 + t * (waveSpeed * 1.00f) + phaseJitter) * a0;
        h += Mathf.Sin(Vector2.Dot(xz, d1) * f1 + t * (waveSpeed * 1.27f) + phaseJitter * 0.7f) * a1;
        h += Mathf.Sin(Vector2.Dot(xz, d2) * f2 + t * (waveSpeed * 1.63f) + phaseJitter * 0.4f) * a2;
        h += Mathf.Sin(Vector2.Dot(xz, d3) * f3 + t * (waveSpeed * 2.05f) + phaseJitter * 0.2f) * a3;

        return h;
    }

    // Finite differences to estimate the wave normal (same as WaveNormalWS in shader)
    Vector3 WaveNormal(Vector3 worldPos, float t)
    {
        float e = normalEpsilon;
        Vector2 xz = new Vector2(worldPos.x, worldPos.z);

        float hC = WaveHeight(xz, t);
        float hX = WaveHeight(xz + new Vector2(e, 0), t);
        float hZ = WaveHeight(xz + new Vector2(0, e), t);

        Vector3 dX = new Vector3(e, (hX - hC) * choppy, 0);
        Vector3 dZ = new Vector3(0, (hZ - hC) * choppy, e);

        return Vector3.Normalize(Vector3.Cross(dZ, dX));
    }
}
