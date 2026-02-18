// Enables the camera depth texture so shaders can access _CameraDepthTexture.
// Needed for the water foam (depth intersection effect).

using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Depth_Texture_Mode : MonoBehaviour {
    void OnEnable() {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }
}