using UnityEngine;
[RequireComponent(typeof(Camera))]
public class EnableDepthTexture : MonoBehaviour {
    void OnEnable() {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }
}