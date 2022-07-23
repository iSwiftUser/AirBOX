//
//  MapViewController.swift
//  ARKitWorkingWithWorldMapData
//
//  Created by Gaurav Sharma on 19/07/22.
//  Copyright © 2022 Jayven Nhan. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController {
    var locationsArray = [CLLocation]()
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var annotations = [MKAnnotation]()

            for location in locationsArray {

                let annotation = MKPointAnnotation()

                annotation.coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

                annotations.append(annotation)
            }

            mapView.addAnnotations(annotations)

            if let lastAnnotation = annotations.last {
                let region = MKCoordinateRegion(center: lastAnnotation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
                mapView.setRegion(region, animated: true)
            }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
