using UnityEngine;

[DisallowMultipleComponent]
public class WaterBob : MonoBehaviour
{
    [Header("Reference (optional)")]
    [Tooltip("If assigned, parameters will be read from this material each frame (or on start).")]
    public Material waterMaterial;

    [Header("Wave Params (match shader)")]
    public float waveAmp = 0.18f;
    public float waveFreq = 1.4f;
    public float waveSpeed = 1.1f;
    public float choppy = 1.0f;
    public float waveSeed = 3.7f;

    [Header("Bobbing")]
    [Tooltip("How strongly the object follows the wave height. 1 = exact.")]
    public float followHeight = 1.0f;

    [Tooltip("Extra vertical offset (e.g. to sit on top of water).")]
    public float heightOffset = 0.0f;

    [Header("Tilt (optional)")]
    public bool tiltToWave = true;

    [Tooltip("How much the object tilts towards the wave normal. 0 = no tilt, 1 = fully match wave normal.")]
    [Range(0, 1)] public float tiltStrength = 0.75f;

    [Tooltip("How fast rotation interpolates to target (bigger = snappier).")]
    public float tiltLerpSpeed = 6.0f;

    [Header("Baseline Rotation")]
    [Tooltip("If true, the script re-captures the current position and rotation as baseline in OnEnable (useful if you move/rotate in editor / via parent).")]
    public bool recaptureBaselineOnEnable = true;

    [Tooltip("Press R in Play Mode to re-capture baseline rotation + position (debug helper).")]
    public bool allowRecaptureWithR = true;

    [Header("Sampling")]
    [Tooltip("Finite difference step for normal estimation (should match shader e ~ 0.06).")]
    public float normalEpsilon = 0.06f;

    [Header("Update Mode")]
    public bool readMaterialEveryFrame = false;

    private Vector3 _basePos;
    private Quaternion _baseRot;

    void OnEnable()
    {
        if (recaptureBaselineOnEnable)
            CaptureBaseline();
    }

    void Start()
    {
        // If OnEnable already captured, this is harmless.
        if (_baseRot == default)
            CaptureBaseline();

        ReadParamsFromMaterial();
    }

    void Update()
    {
        if (allowRecaptureWithR && Input.GetKeyDown(KeyCode.R))
            CaptureBaseline();

        if (readMaterialEveryFrame)
            ReadParamsFromMaterial();

        float t = Time.time; // close enough to shader _Time.y

        // IMPORTANT: sample using the baseline XZ, not the continuously modified transform.
        Vector2 xz = new Vector2(_basePos.x, _basePos.z);
        float h = WaveHeight(xz, t);

        // Bobbing relative to initial base Y (stable, doesn't drift)
        Vector3 p = _basePos;
        p.y = _basePos.y + (h * followHeight) + heightOffset;
        transform.position = p;

        if (tiltToWave)
        {
            // Sample normal at baseline XZ as well
            Vector3 n = WaveNormal(new Vector3(_basePos.x, _basePos.y, _basePos.z), t);

            // Tilt baseline up towards wave normal:
            Quaternion tilt = Quaternion.FromToRotation(_baseRot * Vector3.up, n);

            // Blend tilt strength (don’t ever “lose” baseline rotation)
            Quaternion target = Quaternion.Slerp(_baseRot, tilt * _baseRot, tiltStrength);

            // Smooth
            float k = 1f - Mathf.Exp(-tiltLerpSpeed * Time.deltaTime);
            transform.rotation = Quaternion.Slerp(transform.rotation, target, k);
        }
        else
        {
            // If tilt disabled, keep baseline rotation (so it doesn't reset somewhere else)
            transform.rotation = _baseRot;
        }
    }

    void CaptureBaseline()
    {
        _basePos = transform.position;
        _baseRot = transform.rotation;
        // Reset rotation immediately so there's no lerp delay
        transform.rotation = _baseRot;
    }

    void ReadParamsFromMaterial()
    {
        if (!waterMaterial) return;

        if (waterMaterial.HasProperty("_WaveAmp")) waveAmp = waterMaterial.GetFloat("_WaveAmp");
        if (waterMaterial.HasProperty("_WaveFreq")) waveFreq = waterMaterial.GetFloat("_WaveFreq");
        if (waterMaterial.HasProperty("_WaveSpeed")) waveSpeed = waterMaterial.GetFloat("_WaveSpeed");
        if (waterMaterial.HasProperty("_Choppy")) choppy = waterMaterial.GetFloat("_Choppy");
        if (waterMaterial.HasProperty("_WaveSeed")) waveSeed = waterMaterial.GetFloat("_WaveSeed");
    }

    // --- Wave math: mirror of your shader -----------------------------------

    static float Frac(float x) => x - Mathf.Floor(x);

    static float Hash21(Vector2 p)
    {
        p = new Vector2(Frac(p.x * 123.34f), Frac(p.y * 456.21f));
        float d = Vector2.Dot(p, p + new Vector2(45.32f, 45.32f));
        p += new Vector2(d, d);
        return Frac(p.x * p.y);
    }

    static Vector2 DirFromSeed(float s)
    {
        float a = Frac(s) * (Mathf.PI * 2f);
        return new Vector2(Mathf.Cos(a), Mathf.Sin(a));
    }

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
