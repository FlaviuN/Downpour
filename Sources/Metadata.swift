import Foundation
import PathKit

#if os(Linux)
import JSON
// On Linux we define our own metadata keys that correspond with what exiftool
// uses for metadata key names
private let AVMetadataCommonKeyTitle: String = "Title"
private let AVMetadataCommonKeyCreator: String = ""
private let AVMetadataCommonKeySubject: String = ""
private let AVMetadataCommonKeyDescription: String = ""
private let AVMetadataCommonKeyPublisher: String = "Copyright"
private let AVMetadataCommonKeyContributor: String = ""
private let AVMetadataCommonKeyCreationDate: String = "Date/Time Original"
private let AVMetadataCommonKeyLastModifiedDate: String = ""
private let AVMetadataCommonKeyType: String = "File Type"
private let AVMetadataCommonKeyFormat: String = "MIME Type"
private let AVMetadataCommonKeyIdentifier: String = ""
private let AVMetadataCommonKeySource: String = ""
private let AVMetadataCommonKeyLanguage: String = ""
private let AVMetadataCommonKeyRelation: String = ""
private let AVMetadataCommonKeyLocation: String = ""
private let AVMetadataCommonKeyCopyrights: String = "Copyright"
private let AVMetadataCommonKeyAlbumName: String = "Album"
private let AVMetadataCommonKeyAuthor: String = ""
private let AVMetadataCommonKeyArtist: String = "Artist"
private let AVMetadataCommonKeyArtwork: String = "Picture"
private let AVMetadataCommonKeyMake: String = ""
private let AVMetadataCommonKeyModel: String = ""
private let AVMetadataCommonKeySoftware: String = ""
#else
// Mac OS/iOS includes the AVMetadataCommonKeys in the AVFoundation framework,
// along with the AVAsset class to make retriving file metadata easy
import AVFoundation
#endif

class Metadata {
    // These lazy vars will get metadata for all the common keys normally
    // defined in AVFoundation. The vars are lazy, which means it will only
    // perform the getter once
    lazy var title: String? = { return self.getCommonMetadata(AVMetadataCommonKeyTitle) }()
    lazy var creator: String? = { return self.getCommonMetadata(AVMetadataCommonKeyCreator) }()
    lazy var subject: String? = { return self.getCommonMetadata(AVMetadataCommonKeySubject) }()
    lazy var description: String? = { return self.getCommonMetadata(AVMetadataCommonKeyDescription) }()
    lazy var publisher: String? = { return self.getCommonMetadata(AVMetadataCommonKeyPublisher) }()
    lazy var contributer: String? = { return self.getCommonMetadata(AVMetadataCommonKeyContributor) }()
    lazy var creationDate: Date? = {
        guard let dateString = self.creationDateString else { return nil }
        return self.dateFormatter.date(from: dateString)
    }()
    lazy var creationDateString: String? = { return self.getCommonMetadata(AVMetadataCommonKeyCreationDate) }()
    lazy var lastModifiedDate: Date? = {
        guard let dateString = self.lastModifiedDateString else { return nil }
        return self.dateFormatter.date(from: dateString)
    }()
    lazy var lastModifiedDateString: String? = { return self.getCommonMetadata(AVMetadataCommonKeyLastModifiedDate) }()
    lazy var type: String? = { return self.getCommonMetadata(AVMetadataCommonKeyType) }()
    lazy var format: String? = { return self.getCommonMetadata(AVMetadataCommonKeyFormat) }()
    lazy var identifier: String? = { return self.getCommonMetadata(AVMetadataCommonKeyIdentifier) }()
    lazy var source: String? = { return self.getCommonMetadata(AVMetadataCommonKeySource) }()
    lazy var language: String? = { return self.getCommonMetadata(AVMetadataCommonKeyLanguage) }()
    lazy var relation: String? = { return self.getCommonMetadata(AVMetadataCommonKeyRelation) }()
    lazy var location: String? = { return self.getCommonMetadata(AVMetadataCommonKeyLocation) }()
    lazy var copyrights: String? = { return self.getCommonMetadata(AVMetadataCommonKeyCopyrights) }()
    lazy var album: String? = { return self.getCommonMetadata(AVMetadataCommonKeyAlbumName) }()
    lazy var author: String? = { return self.getCommonMetadata(AVMetadataCommonKeyAuthor) }()
    lazy var artist: String? = { return self.getCommonMetadata(AVMetadataCommonKeyArtist) }()
    lazy var artwork: String? = { return self.getCommonMetadata(AVMetadataCommonKeyArtwork) }()
    lazy var make: String? = { return self.getCommonMetadata(AVMetadataCommonKeyMake) }()
    lazy var model: String? = { return self.getCommonMetadata(AVMetadataCommonKeyModel) }()
    lazy var software: String? = { return self.getCommonMetadata(AVMetadataCommonKeySoftware) }()

    /// A DateFormatter for the attributes that require a date from string in the ISO 8601 format
    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter
    }()

    // The saved metadata items, so that we don't have to continually get the AVAsset or run exiftool
    #if os(Linux)
    private struct Metadata: JSONInitializable {
        private var data: [String: String]

        init(_ str: String) throws {
            try self.init(json: JSON(str))
        }

        init(json: JSON) throws {
            data = [:]

            // Required values. If there are errors here, throw
            data[AVMetadataCommonKeyTitle] = try json.get(AVMetadataCommonKeyTitle)
            data[AVMetadataCommonKeyFormat] = try json.get(AVMetadataCommonKeyFormat)

            // Optional values, ignore errors and set to nil instead
            data[AVMetadataCommonKeyPublisher] = try? json.get(AVMetadataCommonKeyPublisher)
            data[AVMetadataCommonKeyCreationDate] = try? json.get(AVMetadataCommonKeyCreationDate)
            data[AVMetadataCommonKeyType] = try? json.get(AVMetadataCommonKeyType)
            data[AVMetadataCommonKeyCopyrights] = try? json.get(AVMetadataCommonKeyCopyrights)
            data[AVMetadataCommonKeyAlbumName] = try? json.get(AVMetadataCommonKeyAlbumName)
            data[AVMetadataCommonKeyArtist] = try? json.get(AVMetadataCommonKeyArtist)
            data[AVMetadataCommonKeyArtwork] = try? json.get(AVMetadataCommonKeyArtwork)
        }

        public func get(_ key: String) -> String? {
            guard data.keys.contains(key) else { return nil }
            return data[key]
        }
    }

    private var metadataJSON: Metadata?
    #else
    private var metadataItems: [AVMetadataItem]?
    #endif

    /// The path to the file
    private var filepath: Path

    /// The errors that occur within the Metadata class
    private enum MetadataError: Swift.Error {
        case missingDependency(dependency: String, helpText: String)
        case couldNotGetMetadata(error: String)
        case missingMetadataKey(key: String)
    }

    /// Initializer that checks to make sure the dependencies are installed
    init(_ path: Path) throws {
        filepath = path
        try hasDependencies()
    }

    /// Checks to verify the system has any required dependencies.
    /// - Throws: If a dependency is missing
    private func hasDependencies() throws {
        #if os(Linux)
        let (rc, _) = execute("which exiftool")
        if rc != 0 {
            throw MetadataError.missingDependency(dependency: "exiftool",
                helpText: "On Ubuntu systems, try installing the 'libimage-exiftool-perl' package.")
        }
        #endif
    }

    #if os(Linux)
    /// Struct used to capture the stdout and stderr of a command
    private struct Output {
        var stdout: String?
        var stderr: String?
        init (_ out: String?, _ err: String?) {
            stdout = out
            stderr = err
        }
    }

    /**
     Executes a cli command

     - Parameter command: The array of strings that form the command and arguments

     - Returns: A tuple of the return code and output
    */
    private func execute(_ command: String...) -> (Int32, Output) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = command

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        task.launch()
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8)
        let stderr = String(data: stderrData, encoding: .utf8)
        task.waitUntilExit()
        return (task.terminationStatus, Output(stdout, stderr))
    }
    #endif

    /**
     Get the common metadata for the specified common metadata key

     - Parameter key: The common metadata key to retrieve from the common metadata for the file

     - Returns: The string value of the common metadata, or nil. If an error occured, this will print it out
    */
    public func getCommonMetadata(_ key: String) -> String? {
        do {
            // Try and return the Common Metadata value
            return try getCM(key)
        } catch {
            // Print the error that occurred
            print("Failed to get file metadata: \n\t\(error)")
        }
        // Return nil if an error occurs
        return nil
    }

    /**
     Gets the common metadata for the key, throws errors if the key doesn't exist or if metadata could not be retrieved
     - Parameter key: The common metadata key to retrieve from the common metadata for the file

     - Returns: The string value of the common metadata, or nil.
    */
    private func getCM(_ key: String) throws -> String? {
        #if os(Linux)
        // If we're running Linux, check to see if we've saved an exiftool metadata JSON object
        if metadataJSON == nil {
            // If not, run the exiftool command to get the file's metadata
            let (rc, output) = execute("exiftool -b -All -j \(filepath.absolute)")
            // Throw an error if we failed to get the metadata
            guard rc == 0 else {
                var err: String = ""
                if let stderr = output.stderr {
                    err = stderr
                }
                throw MetadataError.couldNotGetMetadata(error: err)
            }
            guard let stdout = output.stdout else {
                throw MetadataError.couldNotGetMetadata(error: "File does not contain any metadata")
            }
            metadataJSON = try Metadata(stdout)
        }
        // Try and retrieve the specified property
        guard let property = metadataJSON?.get(key) else {
            // Throw an error if the key doesn't exist
            throw MetadataError.missingMetadataKey(key: key)
        }
        // Otherwise, return the property
        return property
        #else
        // If we're on macOS/iOS/tvOS/watchOS, check to see if we've saced the common metadataItems
        if metadataItems == nil {
            // If not, get the AVAsset from the filepath url
            let asset = AVAsset(url: filepath.url)
            // Save the common metadata items
            metadataItems = asset.commonMetadata
            // Make sure the asset had common metadata items
            guard let _ = metadataItems else {
                // Throw an error because the asset either has no common metadata, or something happened
                throw MetadataError.couldNotGetMetadata(error: "Unkown problem getting common metadata from AVAsset")
            }
        }
        // Try and get the metadata for the specified key
        let metadata = AVMetadataItem.metadataItems(from: metadataItems!, withKey: key, keySpace: nil)
        // Throws an error if there is no common metadata for the key
        guard metadata.count > 0 else {
            throw MetadataError.missingMetadataKey(key: key)
        }
        // Return the first metadata item's string value
        return metadata.first?.stringValue
        #endif
    }
}
