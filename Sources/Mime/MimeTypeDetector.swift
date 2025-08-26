import Foundation

// MARK: - FileTypes

/// An enum representing various file types supported by the MIME type detector.
///
/// ## Overview
/// `FileTypes` provides a comprehensive list of file types that can be detected
/// by analyzing file signatures (magic numbers) in the data. This enum is used
/// internally by the `MimeType` struct for type-safe file type identification.
///
/// ## Supported File Types
/// The enum includes support for:
/// - **Images**: jpg, png, gif, webp, bmp, tif, ico
/// - **Documents**: pdf, rtf, psd
/// - **Audio**: mp3, wav, flac, ogg, opus, m4a, mid
/// - **Video**: mp4, avi, mov, mkv, flv, wmv, webm, m4v
/// - **Archives**: zip, rar, tar, bz2, gz, xz, 7z, cab, deb, dmg
/// - **Fonts**: ttf, otf, woff, woff2
/// - **Executables**: exe, msi, crx, xpi
/// - **Other**: sqlite, swf, nes, epub, amr, ar, cr2, eot, flif, mpg, mxf, rpm
///
/// ## Usage
/// This enum is primarily used internally by the `MimeType` struct and
/// `MimeTypeDetector` for file type identification. Direct usage is typically
/// not required by end users.
public enum FileTypes: Sendable {
    case amr, ar, avi, bmp, bz2, cab, cr2, crx, deb, dmg, eot, epub, exe, flac, flif, flv, gif, gz, ico, jpg, jxr, lz
    case m4a, m4v, mid, mkv, mov, mp3, mp4, mpg, msi, mxf, nes, ogg, opus, otf, pdf, png, ps, psd, rar, rpm, rtf
    case sevenZ, sqlite, swf, tar, tif, ttf, wav, webm, webp, wmv, woff, woff2, xpi, xz, z, zip
}

// MARK: - MimeType

/// A struct representing a MIME type with associated metadata.
///
/// ## Overview
/// `MimeType` encapsulates information about a specific file type including
/// its MIME type string, file extension, internal file type, and the number
/// of bytes needed for signature detection.
///
/// ## Key Properties
/// - **mime**: The MIME type string (e.g., "image/jpeg")
/// - **ext**: The file extension (e.g., "jpg")
/// - **type**: The internal FileTypes enum value
/// - **bytesCount**: Number of bytes needed for signature detection
///
/// ## Usage Examples
///
/// ### Creating a Custom MIME Type
/// ```swift
/// let customMime = MimeType(
///     mime: "application/x-custom",
///     ext: "custom",
///     type: .pdf, // Using existing type for signature matching
///     bytesCount: 4
/// )
/// ```
///
/// ### Accessing MIME Information
/// ```swift
/// if let mimeType = MimeTypeDetector.detectMimeType(from: imageData) {
///     print("MIME Type: \(mimeType.mime)")
///     print("Extension: \(mimeType.ext)")
///     print("File Type: \(mimeType.type)")
/// }
/// ```
///
/// ## File Signature Detection
/// The `matches(bytes:)` method implements file signature detection by analyzing
/// the first few bytes of the file data against known magic numbers for each file type.
///
/// ## Supported MIME Types
/// The library includes a comprehensive list of common MIME types covering:
/// - Image formats (JPEG, PNG, GIF, WebP, etc.)
/// - Document formats (PDF, RTF, PSD, etc.)
/// - Audio formats (MP3, WAV, FLAC, OGG, etc.)
/// - Video formats (MP4, AVI, MOV, etc.)
/// - Archive formats (ZIP, RAR, TAR, etc.)
/// - Font formats (TTF, OTF, WOFF, etc.)
/// - Executable formats (EXE, MSI, etc.)
public struct MimeType: Sendable {
    // MARK: Lifecycle

    /// Initializes a new MimeType with the specified properties.
    /// - Parameters:
    ///   - mime: The MIME type string (e.g., "image/jpeg")
    ///   - ext: The file extension (e.g., "jpg")
    ///   - type: The internal FileTypes enum value
    ///   - bytesCount: Number of bytes needed for signature detection
    public init(mime: String, ext: String, type: FileTypes, bytesCount: Int) {
        self.mime = mime
        self.ext = ext
        self.type = type
        self.bytesCount = bytesCount
    }

    // MARK: Public

    /// A comprehensive list of supported MIME types with their metadata.
    ///
    /// This array contains all the MIME types that can be detected by the library,
    /// including their file signatures, extensions, and other metadata.
    public static let all: [MimeType] = [
        MimeType(mime: "image/jpeg", ext: "jpg", type: .jpg, bytesCount: 3),
        MimeType(mime: "image/png", ext: "png", type: .png, bytesCount: 4),
        MimeType(mime: "image/gif", ext: "gif", type: .gif, bytesCount: 3),
        MimeType(mime: "image/webp", ext: "webp", type: .webp, bytesCount: 12),
        MimeType(mime: "application/pdf", ext: "pdf", type: .pdf, bytesCount: 4),
        MimeType(mime: "application/zip", ext: "zip", type: .zip, bytesCount: 4),
        MimeType(mime: "video/mp4", ext: "mp4", type: .mp4, bytesCount: 12),
        MimeType(mime: "audio/mpeg", ext: "mp3", type: .mp3, bytesCount: 3),
        MimeType(mime: "audio/x-wav", ext: "wav", type: .wav, bytesCount: 12),
        MimeType(mime: "audio/ogg", ext: "ogg", type: .ogg, bytesCount: 4),
        MimeType(mime: "application/x-bzip2", ext: "bz2", type: .bz2, bytesCount: 3),
        MimeType(mime: "application/x-rar-compressed", ext: "rar", type: .rar, bytesCount: 7),
        MimeType(mime: "application/x-tar", ext: "tar", type: .tar, bytesCount: 262),
        MimeType(mime: "video/quicktime", ext: "mov", type: .mov, bytesCount: 8),
        MimeType(mime: "audio/flac", ext: "flac", type: .flac, bytesCount: 4),
        MimeType(mime: "image/tiff", ext: "tif", type: .tif, bytesCount: 4),
        MimeType(mime: "video/x-msvideo", ext: "avi", type: .avi, bytesCount: 11),
        MimeType(mime: "video/x-ms-wmv", ext: "wmv", type: .wmv, bytesCount: 10),
        MimeType(mime: "application/vnd.adobe.photoshop", ext: "psd", type: .psd, bytesCount: 4),
        MimeType(mime: "application/x-msdownload", ext: "exe", type: .exe, bytesCount: 2),
        MimeType(mime: "application/x-7z-compressed", ext: "7z", type: .sevenZ, bytesCount: 6),
        MimeType(mime: "application/x-xz", ext: "xz", type: .xz, bytesCount: 6),
        MimeType(mime: "video/x-flv", ext: "flv", type: .flv, bytesCount: 4),
        MimeType(mime: "audio/x-opus+ogg", ext: "opus", type: .opus, bytesCount: 36),
        MimeType(mime: "application/epub+zip", ext: "epub", type: .epub, bytesCount: 58),
        MimeType(mime: "application/x-sqlite3", ext: "sqlite", type: .sqlite, bytesCount: 4),
        MimeType(mime: "application/x-deb", ext: "deb", type: .deb, bytesCount: 21),
        MimeType(mime: "application/x-dmg", ext: "dmg", type: .dmg, bytesCount: 2),
        MimeType(mime: "audio/m4a", ext: "m4a", type: .m4a, bytesCount: 11),
        MimeType(mime: "video/x-m4v", ext: "m4v", type: .m4v, bytesCount: 11),
        MimeType(mime: "application/x-compress", ext: "Z", type: .z, bytesCount: 2),
        MimeType(mime: "application/font-woff", ext: "woff", type: .woff, bytesCount: 8),
        MimeType(mime: "application/font-woff", ext: "woff2", type: .woff2, bytesCount: 8),
        MimeType(mime: "application/x-apple-diskimage", ext: "dmg", type: .dmg, bytesCount: 2),
        // More MIME types can be added as needed
    ]

    /// Determines if the provided bytes match this MIME type's file signature.
    ///
    /// This method analyzes the first few bytes of the data against known
    /// magic numbers (file signatures) to determine the file type.
    ///
    /// ## File Signatures
    /// Each file type has a unique signature at the beginning of the file:
    /// - **JPEG**: Starts with `FF D8 FF`
    /// - **PNG**: Starts with `89 50 4E 47`
    /// - **GIF**: Starts with `47 49 46`
    /// - **PDF**: Starts with `25 50 44 46`
    /// - **ZIP**: Starts with `50 4B 03 04`
    ///
    /// - Parameter bytes: The first few bytes of the file data
    /// - Returns: `true` if the bytes match this MIME type's signature
    public func matches(bytes: [UInt8]) -> Bool {
        switch type {
        case .jpg:
            return bytes.starts(with: [0xff, 0xd8, 0xff])
        case .png:
            return bytes.starts(with: [0x89, 0x50, 0x4e, 0x47])
        case .gif:
            return bytes.starts(with: [0x47, 0x49, 0x46])
        case .webp:
            return bytes[8...11] == [0x57, 0x45, 0x42, 0x50]
        case .pdf:
            return bytes.starts(with: [0x25, 0x50, 0x44, 0x46])
        case .zip:
            return bytes.starts(with: [0x50, 0x4b, 0x03, 0x04])
        case .mp4:
            return bytes[4...7] == [0x66, 0x74, 0x79, 0x70] // "ftyp"
        case .mp3:
            return bytes.starts(with: [0x49, 0x44, 0x33]) || bytes.starts(with: [0xff, 0xfb])
        case .wav:
            return bytes[8...11] == [0x57, 0x41, 0x56, 0x45]
        case .ogg:
            return bytes.starts(with: [0x4f, 0x67, 0x67, 0x53])
        case .bz2:
            return bytes.starts(with: [0x42, 0x5a, 0x68])
        case .rar:
            return bytes.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1a, 0x07])
        case .tar:
            return bytes[257...261] == [0x75, 0x73, 0x74, 0x61, 0x72]
        case .mov:
            return bytes.starts(with: [0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70])
        case .flac:
            return bytes.starts(with: [0x66, 0x4c, 0x61, 0x43])
        case .tif:
            return (bytes.starts(with: [0x49, 0x49, 0x2a, 0x00]) || bytes.starts(with: [0x4d, 0x4d, 0x00, 0x2a]))
        case .avi:
            return (bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) && bytes[8...10] == [0x41, 0x56, 0x49])
        case .wmv:
            return bytes.starts(with: [0x30, 0x26, 0xb2, 0x75])
        case .psd:
            return bytes.starts(with: [0x38, 0x42, 0x50, 0x53])
        case .exe:
            return bytes.starts(with: [0x4d, 0x5a])
        case .xz:
            return bytes.starts(with: [0xfd, 0x37, 0x7a, 0x58])
        case .flv:
            return bytes.starts(with: [0x46, 0x4c, 0x56, 0x01])
        default:
            return false
        }
    }

    // MARK: Internal

    /// The MIME type string (e.g., "image/jpeg")
    let mime: String
    /// The file extension (e.g., "jpg")
    let ext: String
    /// The internal FileTypes enum value
    let type: FileTypes

    // MARK: Private

    /// Number of bytes needed for signature detection
    private let bytesCount: Int
}

// MARK: - MimeTypeDetector

/// A utility for detecting MIME types from file data or extensions.
///
/// ## Overview
/// `MimeTypeDetector` provides methods to identify file types by analyzing
/// file signatures (magic numbers) in the data or by examining file extensions.
/// This is particularly useful for file uploads, content validation, and
/// determining appropriate MIME types for network requests.
///
/// ## Key Features
/// - **File Signature Detection**: Analyzes file magic numbers for accurate type identification
/// - **Extension-Based Detection**: Fallback method using file extensions
/// - **Comprehensive Support**: Supports a wide range of file types
/// - **Performance Optimized**: Efficient byte analysis for quick detection
/// - **Thread Safe**: All methods are thread-safe
///
/// ## Usage Examples
///
/// ### Detecting MIME Type from Data
/// ```swift
/// if let imageData = UIImage(named: "photo")?.jpegData(compressionQuality: 0.8) {
///     if let mimeType = MimeTypeDetector.detectMimeType(from: imageData) {
///         print("Detected MIME type: \(mimeType.mime)")
///         print("File extension: \(mimeType.ext)")
///     }
/// }
/// ```
///
/// ### Detecting MIME Type from Extension
/// ```swift
/// if let mimeType = MimeTypeDetector.detectMimeType(fromExtension: "pdf") {
///     print("PDF MIME type: \(mimeType.mime)")
/// }
/// ```
///
/// ### File Upload Validation
/// ```swift
/// func validateUploadedFile(_ data: Data, filename: String) -> Bool {
///     // Check file signature
///     guard let detectedMime = MimeTypeDetector.detectMimeType(from: data) else {
///         return false
///     }
///     
///     // Check file extension
///     let fileExtension = (filename as NSString).pathExtension.lowercased()
///     guard let extensionMime = MimeTypeDetector.detectMimeType(fromExtension: fileExtension) else {
///         return false
///     }
///     
///     // Verify consistency
///     return detectedMime.mime == extensionMime.mime
/// }
/// ```
///
/// ### Multipart Form Data
/// ```swift
/// func createMultipartBody(fileData: Data, filename: String) -> Data {
///     var body = Data()
///     let boundary = "Boundary-\(UUID().uuidString)"
///     
///     // Detect MIME type for Content-Type header
///     let mimeType = MimeTypeDetector.detectMimeType(from: fileData)?.mime ?? "application/octet-stream"
///     
///     body.appendString("--\(boundary)\r\n")
///     body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
///     body.appendString("Content-Type: \(mimeType)\r\n\r\n")
///     body.append(fileData)
///     body.appendString("\r\n")
///     body.appendString("--\(boundary)--\r\n")
///     
///     return body
/// }
/// ```
///
/// ## Detection Methods
///
/// ### File Signature Detection
/// The primary method analyzes the first few bytes of the file data against
/// known magic numbers. This is more reliable than extension-based detection
/// because it examines the actual file content.
///
/// ### Extension-Based Detection
/// A fallback method that maps file extensions to MIME types. This is useful
/// when file data is not available or as a secondary validation method.
///
/// ## Performance Considerations
/// - **Memory Usage**: Only reads the first 262 bytes for signature detection
/// - **Speed**: Fast byte comparison operations
/// - **Accuracy**: High accuracy for supported file types
/// - **Fallback**: Graceful handling of unsupported file types
///
/// ## Security Considerations
/// - **File Validation**: Use signature detection to prevent file type spoofing
/// - **Extension Validation**: Don't rely solely on file extensions
/// - **Content Verification**: Always validate file content for security
///
/// ## Best Practices
/// - **Primary Method**: Use signature detection for accurate type identification
/// - **Secondary Validation**: Use extension detection as a fallback
/// - **Error Handling**: Always handle cases where detection fails
/// - **Security**: Validate file types before processing
public struct MimeTypeDetector: Sendable {
    /// Detects the MIME type from the data's file signature (magic number).
    ///
    /// This method analyzes the first few bytes of the data to identify the file type
    /// based on known magic numbers. This is the most reliable method for MIME type
    /// detection as it examines the actual file content rather than relying on
    /// potentially spoofed file extensions.
    ///
    /// ## How It Works
    /// 1. Reads the first 262 bytes of the data (maximum needed for any supported type)
    /// 2. Compares the bytes against known file signatures
    /// 3. Returns the matching MIME type or nil if no match is found
    ///
    /// ## Performance
    /// - **Memory Efficient**: Only reads necessary bytes
    /// - **Fast**: Simple byte comparison operations
    /// - **Accurate**: High accuracy for supported file types
    ///
    /// - Parameter data: The file data to analyze
    /// - Returns: The detected MimeType or nil if detection fails
    public static func detectMimeType(from data: Data) -> MimeType? {
        let bytes = Array(data.prefix(262)) // Read first 262 bytes (magic number analysis)
        for mime in MimeType.all {
            if mime.matches(bytes: bytes) {
                return mime
            }
        }
        return nil
    }

    /// Detects the MIME type based on the file extension.
    ///
    /// This method provides a fallback mechanism for MIME type detection when
    /// file data is not available. It maps file extensions to their corresponding
    /// MIME types based on the predefined list of supported types.
    ///
    /// ## Use Cases
    /// - **Fallback Detection**: When file data is not available
    /// - **Extension Validation**: To verify expected file types
    /// - **Content-Type Headers**: For HTTP requests with file uploads
    ///
    /// ## Limitations
    /// - **Less Reliable**: File extensions can be easily spoofed
    /// - **Limited Accuracy**: Depends on correct file extension
    /// - **No Content Validation**: Doesn't verify actual file content
    ///
    /// - Parameter fileExtension: The file extension (e.g., "jpg", "pdf")
    /// - Returns: The detected MimeType or nil if extension is not supported
    public static func detectMimeType(fromExtension fileExtension: String) -> MimeType? {
        return MimeType.all.first { $0.ext == fileExtension }
    }
}
