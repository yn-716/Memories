import XCTest
import UIKit
@testable import Memories

@MainActor
final class PetCalendarRenderingTests: XCTestCase {
    func testRendererReturnsImage() {
        let renderer = PetCalendarRenderer(calendar: testCalendar)
        let image = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .hidden,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(image.size.width, 700)
        XCTAssertEqual(image.size.height, 900)
    }

    func testRegisteredDaysProvideThumbnailsAndUnregisteredDaysUseDefaultDrawingPath() {
        let placement = PhotoPlacement(scale: 1.8, offsetX: 0.25, offsetY: -0.2)
        let entry = PetCalendarRenderEntry(
            date: date(year: 2026, month: 6, day: 20),
            thumbnail: makeImage(color: .blue),
            photoPlacement: placement
        )
        let renderer = PetCalendarRenderer(calendar: testCalendar)

        let image = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [entry],
                displayLanguage: .japanese,
                watermarkMode: .hidden,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(image.size, CGSize(width: 700, height: 900))
        XCTAssertEqual(entry.photoPlacement, placement)
    }

    func testRendererKeepsBackgroundLightAfterJPEGEncoding() throws {
        let renderer = PetCalendarRenderer(calendar: testCalendar)
        let image = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .visible,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        let jpegData = try XCTUnwrap(image.jpegData(compressionQuality: 1))
        let jpegImage = try XCTUnwrap(UIImage(data: jpegData))
        let pixel = try XCTUnwrap(jpegImage.rgbaPixel(at: CGPoint(x: 4, y: 4)))
        XCTAssertGreaterThan(pixel.red, 230)
        XCTAssertGreaterThan(pixel.green, 230)
        XCTAssertGreaterThan(pixel.blue, 230)
    }

    func testSmallWidgetDoesNotFallbackToPreviousDayPhotoWhenTodayIsUnregistered() throws {
        let yesterday = date(year: 2026, month: 6, day: 24)
        let today = date(year: 2026, month: 6, day: 25)
        let entry = PetCalendarDayEntry(
            id: "2026-06-24",
            date: yesterday,
            imageFileName: "yesterday.jpg",
            thumbnailFileName: "yesterday-thumb.jpg",
            caption: "",
            photoPlacement: .default,
            overlayStyle: .default,
            createdAt: yesterday,
            updatedAt: yesterday
        )
        let renderedImages = PetCalendarWidgetRenderer().renderAll(
            snapshot: PetCalendarWidgetSnapshot(
                updatedAt: today,
                selectedMonth: date(year: 2026, month: 6, day: 1),
                displayLanguage: .english,
                showsBranding: false
            ),
            entries: [entry],
            thumbnailsByID: ["2026-06-24": makeImage(color: .red)],
            now: today
        )
        let smallImage = try XCTUnwrap(renderedImages.first { $0.family == .small }?.image)

        XCTAssertEqual(redDominantPixelCount(in: smallImage), 0)
    }

    func testMonthGridMarksOutsideMonthSeparatelyFromUnregisteredDays() {
        let cells = PetCalendarDateRules.monthGrid(
            for: date(year: 2026, month: 6, day: 1),
            now: date(year: 2026, month: 6, day: 25),
            calendar: testCalendar
        )

        XCTAssertEqual(cells.first?.id, "2026-05-31")
        XCTAssertFalse(cells.first?.isInDisplayedMonth == true)
    }

    func testWatermarkDrawerIsCalledOnceForVisibleCalendarWatermark() {
        let spy = SpyCalendarWatermarkDrawer()
        let renderer = PetCalendarRenderer(calendar: testCalendar, watermarkDrawer: spy)

        _ = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .visible,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(spy.callCount, 1)
    }

    func testWatermarkDrawerIsNotCalledWhenHidden() {
        let spy = SpyCalendarWatermarkDrawer()
        let renderer = PetCalendarRenderer(calendar: testCalendar, watermarkDrawer: spy)

        _ = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .hidden,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(spy.callCount, 0)
    }

    private var testCalendar: Calendar {
        PetCalendarDateRules.gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    private func redDominantPixelCount(in image: UIImage) -> Int {
        stride(from: 140, through: 420, by: 70).reduce(0) { total, x in
            total + stride(from: 160, through: 400, by: 60).filter { y in
                guard let pixel = image.rgbaPixel(at: CGPoint(x: x, y: y)) else {
                    return false
                }
                return pixel.red > pixel.green + 45 && pixel.red > pixel.blue + 45
            }.count
        }
    }
}

private final class SpyCalendarWatermarkDrawer: CalendarWatermarkDrawing {
    var callCount = 0

    func drawCalendarWatermark(mode: WatermarkMode, in context: CGContext, size: CGSize, bounds: CGRect) {
        callCount += 1
    }
}

private extension UIImage {
    func rgbaPixel(at point: CGPoint) -> (red: Int, green: Int, blue: Int, alpha: Int)? {
        guard let cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let x = min(max(Int(point.x), 0), width - 1)
        let y = min(max(Int(point.y), 0), height - 1)
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = (y * width + x) * 4
        return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]), Int(data[offset + 3]))
    }
}
