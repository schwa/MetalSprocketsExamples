import CBORCoding
import Foundation
import Network

// MARK: - NetworkCBOREncoder

struct NetworkCBOREncoder: NetworkEncoder, Sendable {
    func encode<T>(_ value: T) throws -> Data where T: Encodable {
        try CBOREncoder().encode(value)
    }
}

// MARK: - NetworkCBORDecoder

struct NetworkCBORDecoder: NetworkDecoder, Sendable {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        try CBORDecoder().decode(type, from: data)
    }
}

// MARK: - NetworkCBORCoder

struct NetworkCBORCoder: NetworkCoder, Sendable {
    typealias Encoder = NetworkCBOREncoder
    typealias Decoder = NetworkCBORDecoder

    func makeEncoder() -> NetworkCBOREncoder {
        NetworkCBOREncoder()
    }

    func makeDecoder() -> NetworkCBORDecoder {
        NetworkCBORDecoder()
    }
}
