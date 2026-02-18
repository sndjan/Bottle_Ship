// Connects the UI sliders (Speed, Frequency, Amplitude) to the water material
// and also pushes the values to all Water_Bob scripts so the C# side stays in sync.

using UnityEngine;
using UnityEngine.UI;

public class Water_UI_Controller : MonoBehaviour {
    [SerializeField] private Material waterMaterial;
    [SerializeField] private Water_Bob[] bobbers;  // boat + barrels
    [SerializeField] private Slider ampSlider, freqSlider, speedSlider;

    // Cached property IDs (avoids string lookups every frame)
    static readonly int WaveAmpId   = Shader.PropertyToID("_WaveAmp");
    static readonly int WaveFreqId  = Shader.PropertyToID("_WaveFreq");
    static readonly int WaveSpeedId = Shader.PropertyToID("_WaveSpeed");

    void Awake() {
        // Read current values from the material and initialize sliders
        float amp   = waterMaterial.GetFloat(WaveAmpId);
        float freq  = waterMaterial.GetFloat(WaveFreqId);
        float speed = waterMaterial.GetFloat(WaveSpeedId);

        ampSlider.SetValueWithoutNotify(amp);
        freqSlider.SetValueWithoutNotify(freq);
        speedSlider.SetValueWithoutNotify(speed);

        // Register callbacks
        ampSlider.onValueChanged.AddListener(SetAmp);
        freqSlider.onValueChanged.AddListener(SetFreq);
        speedSlider.onValueChanged.AddListener(SetSpeed);

        // Apply once so everything starts in sync
        SetAmp(amp);
        SetFreq(freq);
        SetSpeed(speed);
    }

    // Each setter updates both the shader property and all bobber scripts
    void SetAmp(float v) {
        waterMaterial.SetFloat(WaveAmpId, v);
        foreach (var b in bobbers) if (b) b.waveAmp = v;
    }

    void SetFreq(float v) {
        waterMaterial.SetFloat(WaveFreqId, v);
        foreach (var b in bobbers) if (b) b.waveFreq = v;
    }

    void SetSpeed(float v) {
        waterMaterial.SetFloat(WaveSpeedId, v);
        foreach (var b in bobbers) if (b) b.waveSpeed = v;
    }
}
