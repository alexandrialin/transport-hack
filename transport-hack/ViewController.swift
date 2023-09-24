import UIKit
import RealityKit
import ARKit
import CoreLocation
import Vision

class ViewController: UIViewController, CLLocationManagerDelegate, ARSessionDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var arView: ARView!
    let tableView = UITableView()
    var locationManager: CLLocationManager!
    var userLocation: CLLocation?
    var busStops: [BusStop] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ViewController initialized")
        
        // Core Location Setup
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // AR Configuration
        let configuration = ARWorldTrackingConfiguration()
        if let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: Bundle.main) {
            configuration.detectionImages = trackedImages
            configuration.maximumNumberOfTrackedImages = 2
        }
        arView.session.run(configuration)
        arView.session.delegate = self
        
        // Set up constraints for ARView
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leftAnchor.constraint(equalTo: view.leftAnchor),
            arView.rightAnchor.constraint(equalTo: view.rightAnchor),
            arView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7)
        ])
        
        // Setup the table view
        setupTableView()
    }
    
    func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BusStopCell")
        
        // Constraints for the tableView to occupy the bottom part of the screen
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: arView.bottomAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return busStops.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BusStopCell", for: indexPath)
        cell.textLabel?.text = busStops[indexPath.row].name
        return cell
    }
    
    // Core Location delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("Location Updated: \(location)")
            userLocation = location
            fetchNearbyBusStops(location: location)
        }
    }
    
    func recognizeStopID(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("Failed to recognize text: \(error)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            for observation in observations {
                let potentialText = observation.topCandidates(1).first?.string ?? ""
                let components = potentialText.split(separator: " ")
                if let index = components.firstIndex(where: { $0.caseInsensitiveCompare("Stop") == .orderedSame }), index < components.count - 2, components[index + 1].caseInsensitiveCompare("ID") == .orderedSame {
                    let stopID = components[index + 2]
                    completion(String(stopID))
                    return
                }

            }

            completion(nil)
        }
        
        try? requestHandler.perform([request])
    }
    
    func fetchNearbyBusStops(location: CLLocation) {
        let radius: Double = 1000
        let apiKey = "AIzaSyDPEV1OqNFXW3_zZlxln-wt3Mi70g0aptQ" // Replace with your Google Places API Key
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.coordinate.latitude),\(location.coordinate.longitude)&radius=\(radius)&type=bus_station&key=\(apiKey)"
        
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let error = error {
                    // Print network error
                    print("Network error: \(error.localizedDescription)")
                    return
                }
                
                if let data = data {
                    do {
                        let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
                        if let results = jsonResult?["results"] as? [[String: Any]] {
                            self.busStops = results.compactMap { (dict) -> BusStop? in
                                if let id = dict["place_id"] as? String,
                                   let name = dict["name"] as? String,
                                   let geometry = dict["geometry"] as? [String: Any],
                                   let location = geometry["location"] as? [String: Double],
                                   let lat = location["lat"],
                                   let lon = location["lng"] {
                                    return BusStop(id: id, name: name, location: CLLocation(latitude: lat, longitude: lon))
                                }
                                return nil
                            }
                            
                            // Print if no bus stops are found
                            if self.busStops.isEmpty {
                                print("No bus stops found within the specified radius.")
                            } else {
                                // Print the fetched bus stops to the console
                                for busStop in self.busStops {
                                    print("Stop ID: \(busStop.id), Name: \(busStop.name), Location: \(busStop.location.coordinate.latitude), \(busStop.location.coordinate.longitude)")
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    } catch {
                        print("Failed to parse JSON: \(error)")
                    }
                }
            }.resume()
        }
    }
    
    // ARSession delegate
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let imageAnchor = anchor as? ARImageAnchor,
               let image = UIImage(named: imageAnchor.referenceImage.name ?? "") {  // Assuming you have a UIImage with the same name
                recognizeStopID(in: image) { stopID in
                    guard let id = stopID else {
                        print("Failed to recognize the Stop ID in the image.")
                        return
                    }
                    
                    print("Recognized Stop ID: \(id)")
                    
                    let textEntity = ModelEntity(mesh: .generateText("Stop ID: \(id)"))
                    textEntity.scale = [0.001, 0.001, 0.001]
                    textEntity.transform.rotation = simd_quatf(angle: -Float.pi / 2, axis: [1, 0, 0])
                    textEntity.scale = [0.001, 0.001, -0.001]

                    let anchorEntity = AnchorEntity(anchor: imageAnchor)
                    anchorEntity.addChild(textEntity)
                    self.arView.scene.addAnchor(anchorEntity)
                }
            }
        }
    }
    
}

struct BusStop {
    var id: String
    var name: String
    var location: CLLocation
}
