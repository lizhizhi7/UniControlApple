//
//  VisionProcessor.swift
//  UniControl
//
//  OCR and vision processing for element detection fallback
//

import Foundation
import Vision
import CoreGraphics
import AppKit

/// Result of text recognition in an image
public struct VisionTextResult {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float

    public init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// Recognize all text in an image using Vision OCR
/// - Parameter image: The CGImage to process
/// - Returns: Array of recognized text results with bounding boxes
@available(macOS 10.15, *)
public func recognizeText(in image: CGImage) -> [VisionTextResult] {
    var results: [VisionTextResult] = []
    let semaphore = DispatchSemaphore(value: 0)

    // Create text recognition request
    let request = VNRecognizeTextRequest { request, error in
        defer { semaphore.signal() }

        guard error == nil else {
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }

        // Extract text and bounding boxes
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }

            let text = topCandidate.string
            let confidence = topCandidate.confidence

            // Convert normalized coordinates to image coordinates
            let imageHeight = CGFloat(image.height)
            let imageWidth = CGFloat(image.width)

            let boundingBox = observation.boundingBox
            let rect = CGRect(
                x: boundingBox.origin.x * imageWidth,
                y: (1.0 - boundingBox.origin.y - boundingBox.height) * imageHeight,  // Flip Y axis
                width: boundingBox.width * imageWidth,
                height: boundingBox.height * imageHeight
            )

            results.append(VisionTextResult(
                text: text,
                boundingBox: rect,
                confidence: confidence
            ))
        }
    }

    // Configure request for best accuracy
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    // Perform request
    let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

    do {
        try requestHandler.perform([request])
    } catch {
        return []
    }

    semaphore.wait()
    return results
}

/// Find text in an image using fuzzy matching
/// - Parameters:
///   - searchText: The text to search for
///   - image: The CGImage to search in
///   - fuzzy: Whether to use fuzzy matching (default: true)
///   - threshold: Minimum similarity score for fuzzy matching (0.0 to 1.0, default: 0.6)
/// - Returns: Array of matching text results, sorted by similarity (highest first)
@available(macOS 10.15, *)
public func findText(_ searchText: String, in image: CGImage, fuzzy: Bool = true, threshold: Double = 0.6) -> [VisionTextResult] {
    let allText = recognizeText(in: image)

    if !fuzzy {
        // Exact matching (case-insensitive)
        return allText.filter { $0.text.lowercased() == searchText.lowercased() }
    }

    // Fuzzy matching using similarity score
    var matches: [(result: VisionTextResult, similarity: Double)] = []

    for result in allText {
        let similarity = similarityScore(searchText, result.text)
        if similarity >= threshold {
            matches.append((result: result, similarity: similarity))
        }
    }

    // Sort by similarity (highest first)
    matches.sort { $0.similarity > $1.similarity }

    return matches.map { $0.result }
}

/// Compare two images and return a similarity score
/// - Parameters:
///   - before: The first image
///   - after: The second image
/// - Returns: Similarity score from 0.0 (completely different) to 1.0 (identical)
@available(macOS 10.15, *)
public func compareImages(_ before: CGImage, _ after: CGImage) -> Float {
    // Ensure images have same dimensions for comparison
    guard before.width == after.width && before.height == after.height else {
        return 0.0
    }

    // Convert to histograms and compare
    let beforeHistogram = createHistogram(from: before)
    let afterHistogram = createHistogram(from: after)

    return compareHistograms(beforeHistogram, afterHistogram)
}

/// Create a color histogram from an image
/// - Parameter image: The CGImage to process
/// - Returns: Array of normalized histogram values (256 bins for grayscale)
private func createHistogram(from image: CGImage) -> [Float] {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8

    // Create context for pixel data extraction
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return Array(repeating: 0, count: 256)
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Build histogram (grayscale: 256 bins)
    var histogram = [Int](repeating: 0, count: 256)

    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * bytesPerPixel
            let r = Float(pixelData[offset])
            let g = Float(pixelData[offset + 1])
            let b = Float(pixelData[offset + 2])

            // Convert to grayscale using luminance formula
            let gray = Int(0.299 * r + 0.587 * g + 0.114 * b)
            histogram[gray] += 1
        }
    }

    // Normalize histogram
    let totalPixels = Float(width * height)
    return histogram.map { Float($0) / totalPixels }
}

/// Compare two histograms using correlation method
/// - Parameters:
///   - hist1: First histogram
///   - hist2: Second histogram
/// - Returns: Similarity score from 0.0 to 1.0
private func compareHistograms(_ hist1: [Float], _ hist2: [Float]) -> Float {
    guard hist1.count == hist2.count else {
        return 0.0
    }

    // Calculate mean values
    let mean1 = hist1.reduce(0, +) / Float(hist1.count)
    let mean2 = hist2.reduce(0, +) / Float(hist2.count)

    // Calculate correlation coefficient
    var numerator: Float = 0
    var denom1: Float = 0
    var denom2: Float = 0

    for i in 0..<hist1.count {
        let diff1 = hist1[i] - mean1
        let diff2 = hist2[i] - mean2

        numerator += diff1 * diff2
        denom1 += diff1 * diff1
        denom2 += diff2 * diff2
    }

    let denominator = sqrt(denom1 * denom2)

    if denominator == 0 {
        return hist1 == hist2 ? 1.0 : 0.0
    }

    // Correlation ranges from -1 to 1, normalize to 0 to 1
    let correlation = numerator / denominator
    return (correlation + 1.0) / 2.0
}

/// Find the center point of a bounding box
/// - Parameter boundingBox: The CGRect bounding box
/// - Returns: CGPoint representing the center
public func getCenterPoint(of boundingBox: CGRect) -> CGPoint {
    return CGPoint(
        x: boundingBox.origin.x + boundingBox.width / 2,
        y: boundingBox.origin.y + boundingBox.height / 2
    )
}

/// Convert window-relative coordinates to screen coordinates
/// - Parameters:
///   - point: The window-relative point
///   - windowOrigin: The window's origin in screen coordinates
/// - Returns: Screen-absolute coordinates
public func convertToScreenCoordinates(point: CGPoint, windowOrigin: CGPoint) -> CGPoint {
    return CGPoint(
        x: windowOrigin.x + point.x,
        y: windowOrigin.y + point.y
    )
}
