import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("running")
        
        // Use ARWorldTrackingConfiguration for vertical surfaces
        let configuration = ARWorldTrackingConfiguration()

        if let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: Bundle.main) {
            configuration.detectionImages = trackedImages
            configuration.maximumNumberOfTrackedImages = 2
        }
        
        arView.session.run(configuration)
        
        arView.session.delegate = self
    }
}

extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let imageAnchor = anchor as? ARImageAnchor {
                let referenceImageName = imageAnchor.referenceImage.name
                
                // Print the name of the recognized image:
                print("Recognized image: \(referenceImageName ?? "Unknown")")
                
                // Create a text entity for the recognized image
                let textEntity = ModelEntity(mesh: .generateText(referenceImageName ?? "Unknown"))
                textEntity.scale = [0.001, 0.001, 0.001] // scale down the text size for AR
                
                // Adjust the text entity's orientation for vertical surfaces
                textEntity.transform.rotation = simd_quatf(angle: -Float.pi / 2, axis: [1, 0, 0])
                textEntity.scale = [0.001, 0.001, -0.001] // Mirror along the z-axis

                
                let anchorEntity = AnchorEntity(anchor: imageAnchor)
                anchorEntity.addChild(textEntity)
                arView.scene.addAnchor(anchorEntity)
            }
        }
    }
}
