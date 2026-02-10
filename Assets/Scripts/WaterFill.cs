using UnityEngine;

public class WaterFill : MonoBehaviour
{
    [Header("Assign")]
    public Transform waterVolume;   // z.B. WaterVolume
    public Transform waterSurface;  // z.B. WaterSurface

    [Header("Settings")]
    [Range(0f, 1f)] public float fill = 0.5f;

    // Höhe des "vollen" Wasservolumens in local space (vorher messen/setzen)
    public float fullHeight = 1.0f;

    // Y-Position des Bodens in local space (wo Wasser anfangen soll)
    public float bottomY = 0.0f;

    void Update()
    {
        // Volume: Skalieren in Y
        Vector3 s = waterVolume.localScale;
        s.y = Mathf.Max(0.0001f, fill);
        waterVolume.localScale = s;

        // Cylinder pivot ist in der Mitte -> Position so, dass Boden auf bottomY bleibt
        float currentHeight = fullHeight * fill;
        float centerY = bottomY + currentHeight * 0.5f;
        Vector3 p = waterVolume.localPosition;
        p.y = centerY;
        waterVolume.localPosition = p;

        // Surface auf die Oberkante setzen
        Vector3 sp = waterSurface.localPosition;
        sp.y = bottomY + currentHeight;
        waterSurface.localPosition = sp;
    }
}
