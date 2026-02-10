using UnityEngine;
using UnityEngine.UI;

public class WaterUIController : MonoBehaviour
{
    [SerializeField] private Material waterMaterial;
    [SerializeField] private WaterBob[] bobbers; // boat + barrels
    [SerializeField] private Slider ampSlider, freqSlider, speedSlider;

    static readonly int WaveAmpId   = Shader.PropertyToID("_WaveAmp");
    static readonly int WaveFreqId  = Shader.PropertyToID("_WaveFreq");
    static readonly int WaveSpeedId = Shader.PropertyToID("_WaveSpeed");

    void Awake()
    {
        float amp   = waterMaterial.GetFloat(WaveAmpId);
        float freq  = waterMaterial.GetFloat(WaveFreqId);
        float speed = waterMaterial.GetFloat(WaveSpeedId);

        ampSlider.SetValueWithoutNotify(amp);
        freqSlider.SetValueWithoutNotify(freq);
        speedSlider.SetValueWithoutNotify(speed);

        ampSlider.onValueChanged.AddListener(SetAmp);
        freqSlider.onValueChanged.AddListener(SetFreq);
        speedSlider.onValueChanged.AddListener(SetSpeed);

        // apply once
        SetAmp(amp);
        SetFreq(freq);
        SetSpeed(speed);
    }

    void SetAmp(float v)
    {
        waterMaterial.SetFloat(WaveAmpId, v);
        foreach (var b in bobbers) if (b) b.waveAmp = v;
    }
    void SetFreq(float v)
    {
        waterMaterial.SetFloat(WaveFreqId, v);
        foreach (var b in bobbers) if (b) b.waveFreq = v;
    }
    void SetSpeed(float v)
    {
        waterMaterial.SetFloat(WaveSpeedId, v);
        foreach (var b in bobbers) if (b) b.waveSpeed = v;
    }
}
