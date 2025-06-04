import Foundation
import Socket

let socketPath = "/tmp/corndeliveryutility/serv.sock"

typealias Handler = (Data, String?) -> Void

struct Test : Codable {
    let msg: String
}

struct SocketServer {
    public struct Envelope: Codable {
        let type: String
        let id: String
        let data: Data
        let isResponse: Bool
    }

    var pendingResponses: [String: (Data) -> Void] = [:]

    func NewReqID() -> String {
        UUID().uuidString
    }

    public func Emit<T: Codable>(socket: Socket, message: T, isResponse: Bool = false, id: String? = nil) throws {
        let id = id ?? NewReqID()
        let data = try JSONEncoder().encode(message)
        let envelope = SocketServer.Envelope(type: String(describing: T.self), id: id, data: data, isResponse: isResponse)
        let envelopeData = try JSONEncoder().encode(envelope)

        var length = UInt32(envelopeData.count).bigEndian
        let lengthBytes = withUnsafeBytes(of: &length) { Data($0) }

        try socket.write(from: lengthBytes)
        try socket.write(from: envelopeData)
    }

    public func Recieve<T: Codable>(socket: Socket, into type: T.Type) throws -> T {
        func readExactly(count: Int) throws -> Data {
            var buffer = Data()
            while buffer.count < count {
                var chunk = Data(count: count - buffer.count)
                let bytesRead = try chunk.withUnsafeMutableBytes { ptr -> Int in
                    guard let baseAddress = ptr.baseAddress else {
                        throw NSError(domain: "Buffer has no base address", code: -1)
                    }
                    return try socket.read(into: baseAddress.assumingMemoryBound(to: Int8.self), bufSize: count - buffer.count)
                }
                guard bytesRead > 0 && bytesRead < 10_000_000  else {
                    throw NSError(domain: "Socket closed or read error", code: -2)
                }
                buffer.append(chunk.prefix(bytesRead))
                print("read chunk: \(bytesRead) bytes, total so far: \(buffer.count) of \(count)")
            }
            return buffer
        }
        
        let lengthBuffer = try readExactly(count: 4)
        print("lengthBuffer hex:", lengthBuffer.map { String(format: "%02x", $0) }.joined())
        
        let length = lengthBuffer.withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        print("length:", length)
        
        let dataBuffer = try readExactly(count: Int(length))
        print("dataBuffer size:", dataBuffer.count)

        let envelope = try JSONDecoder().decode(SocketServer.Envelope.self, from: dataBuffer)
        print(envelope)
        let message = try JSONDecoder().decode(type, from: envelope.data)
        return message
    }
}

func NewConn(_ client: Socket) async throws {
    try SocketServer().Emit(socket: client, message: Test(msg: "str8 bine"))
    while true {
        let x = try SocketServer().Recieve(socket: client, into: Test.self)
        print(x)
    }
}

do {
    try? FileManager.default.removeItem(atPath: socketPath)

    let server = try Socket.create(family: .unix, type: .stream, proto: .unix)
    try server.listen(on: socketPath)
    print("server listening on \(socketPath)")

    while true {
        let client = try server.acceptClientConnection()
        print("client connected")

        Task.detached {
            do {
                try await NewConn(client)
            } catch {
                print("error \(error)")
            }
        }
    }

} catch {
    print("error: \(error)")
}
