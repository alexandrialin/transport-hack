import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("running")
        
        let configuration = ARImageTrackingConfiguration()

        if let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "Your AR Resource Group Name", bundle: Bundle.main) {
            configuration.trackingImages = trackedImages
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
                
                // Now handle the recognized image.
                // For this example, let's just print the name of the recognized image:
                print("Recognized image: \(referenceImageName ?? "Unknown")")
                
                // Here, you can add RealityKit entities or other actions based on the recognized image.
                // Example: Display a text entity above the recognized image.
                let textEntity = ModelEntity(mesh: .generateText(referenceImageName ?? "Unknown"))
                textEntity.scale = [0.001, 0.001, 0.001] // scale down the text size for AR
                arView.installGestures([.all], for: textEntity)
                
                let anchorEntity = AnchorEntity(anchor: imageAnchor)
                anchorEntity.addChild(textEntity)
                arView.scene.addAnchor(anchorEntity)
            }
        }
    }
}
