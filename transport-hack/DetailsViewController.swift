import UIKit
import RealityKit
import ARKit
import CoreLocation
import Vision

class DetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var predictions: [Prediction]?
    
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PredictionTableViewCell.self, forCellReuseIdentifier: "PredictionCell")
        tableView.rowHeight = 70 // Adjust this value as needed
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PredictionCell", for: indexPath) as! PredictionTableViewCell
        
        if let prediction = predictions?[indexPath.row] {
            cell.routeLabel.text = prediction.RouteName
            cell.timeLabel.text = formatDepartureTime(utcDate: prediction.PredictedDeparture)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(hex: "#8C52FF", alpha: 0.1)
    }

    func formatDepartureTime(utcDate: Date) -> String {
        let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        let pacificDateFormatter = DateFormatter()
        pacificDateFormatter.timeZone = pacificTimeZone
        pacificDateFormatter.dateFormat = "h:mm a"
        return pacificDateFormatter.string(from: utcDate)
    }
}



extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: alpha
        )
    }
}
