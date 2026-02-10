using UnityEngine;

public class BoatBob : MonoBehaviour
{
    [Header("Reference")]
    public Transform waterSurface;   // Optional: nur als Bezug
    public Transform bottleRoot;     // Das Objekt, dessen Local Space die Wasseroberfläche definiert (z.B. WaterSurface oder Water)

    [Header("Wave 1")]
    public float amp1 = 0.02f;
    public float len1 = 0.25f;
    public float speed1 = 1.0f;
    public Vector2 dir1 = new Vector2(1, 0);
    public float steep1 = 0.35f;

    [Header("Wave 2")]
    public float amp2 = 0.012f;
    public float len2 = 0.15f;
    public float speed2 = 1.35f;
    public Vector2 dir2 = new Vector2(0.4f, 0.9f);
    public float steep2 = 0.25f;

    [Header("Boat")]
    public float heightOffset = 0.0f;    // Boot sitzt evtl. etwas über Wasser
    public float tiltStrength = 10.0f;   // Grad Skalierung

    Vector3 baseLocalPos;
    Quaternion baseLocalRot;

    void Start()
    {
        baseLocalPos = transform.localPosition;
        baseLocalRot = transform.localRotation;
        if (bottleRoot == null) bottleRoot = transform.parent;
    }

    float GerstnerY(Vector2 xz, float amp, float len, float speed, Vector2 dir)
    {
        dir.Normalize();
        float k = 2 * Mathf.PI / Mathf.Max(0.0001f, len);
        float f = k * Vector2.Dot(dir, xz) + Time.time * speed;
        return amp * Mathf.Sin(f);
    }

    Vector2 GerstnerGradient(Vector2 xz, float amp, float len, float speed, Vector2 dir, float steep)
    {
        dir.Normalize();
        float k = 2 * Mathf.PI / Mathf.Max(0.0001f, len);
        float f = k * Vector2.Dot(dir, xz) + Time.time * speed;

        // dy/dx, dy/dz (approx) from sin -> cos
        float c = Mathf.Cos(f);
        // gradient proportional to k*amp*cos(...)
        Vector2 grad = dir * (k * amp * c * steep);
        return grad;
    }

    void Update()
    {
        // Boat position in bottleRoot local space
        Vector3 local = transform.localPosition;
        Vector3 localInRoot = (bottleRoot == null) ? local : bottleRoot.InverseTransformPoint(transform.position);

        // Use xz on the water plane in ROOT local space
        Vector2 xz = new Vector2(localInRoot.x, localInRoot.z);

        float y =
            GerstnerY(xz, amp1, len1, speed1, dir1) +
            GerstnerY(xz, amp2, len2, speed2, dir2);

        // Apply height
        Vector3 newLocalPos = baseLocalPos;
        newLocalPos.y = baseLocalPos.y + y + heightOffset;
        transform.localPosition = newLocalPos;

        // Tilt from gradient
        Vector2 g =
            GerstnerGradient(xz, amp1, len1, speed1, dir1, steep1) +
            GerstnerGradient(xz, amp2, len2, speed2, dir2, steep2);

        // g.x ~ slope along dir.x, g.y ~ slope along dir.y (mapped to x/z)
        float tiltX = -g.y * tiltStrength; // pitch
        float tiltZ =  g.x * tiltStrength; // roll

        transform.localRotation = baseLocalRot * Quaternion.Euler(tiltX, 0f, tiltZ);
    }
}
