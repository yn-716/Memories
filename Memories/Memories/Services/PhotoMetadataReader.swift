import CoreLocation
import Foundation
import ImageIO

struct PhotoMetadata: Hashable {
    var capturedAt: Date?
    var locationText: String?
}

struct PhotoMetadataReader {
    func metadata(from data: Data, allowsLocationSuggestion: Bool = true) async -> PhotoMetadata {
        let rawMetadata = readRawMetadata(from: data, allowsLocationSuggestion: allowsLocationSuggestion)
        let locationText = allowsLocationSuggestion ? await locationText(for: rawMetadata.coordinate) : nil

        return PhotoMetadata(
            capturedAt: rawMetadata.capturedAt,
            locationText: locationText
        )
    }

    private func readRawMetadata(from data: Data, allowsLocationSuggestion: Bool) -> RawPhotoMetadata {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return RawPhotoMetadata()
        }

        return RawPhotoMetadata(
            capturedAt: capturedAt(from: properties),
            coordinate: allowsLocationSuggestion ? coordinate(from: properties) : nil
        )
    }

    private func capturedAt(from properties: [String: Any]) -> Date? {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        let dateCandidates = [
            exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String,
            exif?[kCGImagePropertyExifDateTimeDigitized as String] as? String,
            tiff?[kCGImagePropertyTIFFDateTime as String] as? String
        ]

        return dateCandidates.compactMap { $0 }.compactMap(parseDate).first
    }

    private func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "yyyy:MM:dd HH:mm:ss",
            "yyyy:MM:dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format

            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    private func coordinate(from properties: [String: Any]) -> CLLocationCoordinate2D? {
        guard let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }

        guard
            let rawLatitude = gps[kCGImagePropertyGPSLatitude as String] as? CLLocationDegrees,
            let rawLongitude = gps[kCGImagePropertyGPSLongitude as String] as? CLLocationDegrees
        else {
            return nil
        }

        let latitudeRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String)?.uppercased()
        let longitudeRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String)?.uppercased()
        let latitude = latitudeRef == "S" ? -rawLatitude : rawLatitude
        let longitude = longitudeRef == "W" ? -rawLongitude : rawLongitude

        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func locationText(for coordinate: CLLocationCoordinate2D?) async -> String? {
        guard let coordinate else {
            return nil
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            if let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first {
                let text = formattedLocationText(from: placemark)
                if !text.isEmpty {
                    return text
                }
            }
        } catch {
            // Reverse geocoding can fail offline; avoid exposing raw GPS coordinates as card text.
        }

        return nil
    }

    private func formattedLocationText(from placemark: CLPlacemark) -> String {
        let candidates = [
            placemark.locality,
            placemark.subLocality,
            placemark.administrativeArea,
            placemark.country
        ]

        var uniqueParts: [String] = []
        for candidate in candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !candidate.isEmpty {
            if !uniqueParts.contains(candidate) {
                uniqueParts.append(candidate)
            }
        }

        return uniqueParts.prefix(2).joined(separator: " ")
    }

}

private struct RawPhotoMetadata {
    var capturedAt: Date?
    var coordinate: CLLocationCoordinate2D?
}
