import Foundation

/// Parses the binary plist blobs stored in `secureLocations.value`.
struct BplistParser: Sendable {
    enum ParseError: Error, LocalizedError {
        case notADictionary
        case missingCoordinates

        var errorDescription: String? {
            switch self {
            case .notADictionary: return "Location blob is not a plist dictionary"
            case .missingCoordinates: return "Location blob missing latitude/longitude"
            }
        }
    }

    static func parseLocation(from blob: Data) throws -> LocationUpdate {
        let raw = try PropertyListSerialization.propertyList(from: blob, options: [], format: nil)
        guard let dict = raw as? [String: Any] else {
            throw ParseError.notADictionary
        }

        guard let lat = dict["latitude"] as? Double,
              let lon = dict["longitude"] as? Double else {
            throw ParseError.missingCoordinates
        }

        // Apple serialises timestamps as NSDate (seconds since 2001-01-01).
        let ts: Date
        if let date = dict["timestamp"] as? Date {
            ts = date
        } else if let secs = dict["timestamp"] as? Double {
            ts = Date(timeIntervalSinceReferenceDate: secs)
        } else {
            ts = Date(timeIntervalSinceReferenceDate: 0)
        }

        return LocationUpdate(
            latitude:            lat,
            longitude:           lon,
            horizontalAccuracy:  dict["horizontalAccuracy"] as? Double ?? 0,
            verticalAccuracy:    dict["verticalAccuracy"]   as? Double ?? 0,
            altitude:            dict["altitude"]           as? Double ?? 0,
            speed:               dict["speed"]              as? Double ?? -1,
            course:              dict["course"]             as? Double ?? -1,
            timestamp:           ts,
            motionActivityState: dict["motionActivityState"] as? Int ?? 0,
            publishReason:       dict["publishReason"]      as? Int ?? 0,
            locationLabel:       dict["locationLabel"]      as? String ?? "",
            findMyId:            dict["findMyId"]           as? String ?? ""
        )
    }
}
