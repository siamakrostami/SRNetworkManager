import Foundation

/// Extensions to the Data type for enhanced functionality.
///
/// This extension provides utility methods for working with Data objects,
/// particularly useful in network operations and data processing.
extension Data {
    /// Appends a UTF-8 encoded string to the Data instance.
    ///
    /// ## Overview
    /// This method provides a convenient way to append string data to an existing
    /// Data object. It automatically handles UTF-8 encoding and safely appends
    /// the resulting bytes.
    ///
    /// ## Usage Examples
    ///
    /// ### Basic String Appending
    /// ```swift
    /// var data = Data()
    /// data.appendString("Hello, World!")
    /// // data now contains the UTF-8 bytes of "Hello, World!"
    /// ```
    ///
    /// ### Building Multipart Form Data
    /// ```swift
    /// var body = Data()
    /// let boundary = "Boundary-\(UUID().uuidString)"
    /// 
    /// // Add form field
    /// body.appendString("--\(boundary)\r\n")
    /// body.appendString("Content-Disposition: form-data; name=\"username\"\r\n\r\n")
    /// body.appendString("john_doe\r\n")
    /// 
    /// // Add file data
    /// body.appendString("--\(boundary)\r\n")
    /// body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
    /// body.appendString("Content-Type: image/jpeg\r\n\r\n")
    /// body.append(imageData)
    /// body.appendString("\r\n")
    /// 
    /// // End boundary
    /// body.appendString("--\(boundary)--\r\n")
    /// ```
    ///
    /// ### Building JSON-like Structures
    /// ```swift
    /// var jsonData = Data()
    /// jsonData.appendString("{\n")
    /// jsonData.appendString("  \"name\": \"John Doe\",\n")
    /// jsonData.appendString("  \"age\": 30,\n")
    /// jsonData.appendString("  \"city\": \"New York\"\n")
    /// jsonData.appendString("}")
    /// ```
    ///
    /// ## Error Handling
    /// The method safely handles encoding failures:
    /// - If the string cannot be encoded as UTF-8, no data is appended
    /// - No exception is thrown, making it safe for use in critical paths
    ///
    /// ## Performance Considerations
    /// - **Encoding Overhead**: Each call involves UTF-8 encoding
    /// - **Memory Allocation**: New Data objects are created for each string
    /// - **Efficiency**: For large amounts of string data, consider using
    ///   `String.data(using:)` directly and appending the result
    ///
    /// ## Thread Safety
    /// This method modifies the Data instance in place and is not thread-safe.
    /// Ensure proper synchronization when using from multiple threads.
    ///
    /// - Parameter string: The string to append to the Data instance.
    ///   The string will be UTF-8 encoded before appending.
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
