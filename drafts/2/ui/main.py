import struct
import json
from socket import socket as sbus, AF_UNIX, SOCK_STREAM
import base64
from typing import Type, TypeVar
from dataclasses import dataclass

T = TypeVar('T')

@dataclass
class Envelope:
    type: str
    id: str
    data: dict
    isResponse: bool

class SocketClient:
    sock: sbus

    def __init__(self, path: str) -> None:
        self.sock = sbus(AF_UNIX, SOCK_STREAM)
        try:
            self.sock.connect(path)
        except Exception as e:
            print(f"{path} something was wrong {repr(e)}")
            exit(69)
        return

    def __del__(self) -> None:
        self.sock.close()
        try:
            self.sock.close()
        except Exception:
            pass

    def recieve(self, cls: Type[T]) -> T:
        length_buf = self.sock.recv(4)
        if len(length_buf) < 4:
            raise ValueError("socket closed or incomplete length prefix")

        length = struct.unpack('>I', length_buf)[0]
        if length <= 0 or length > 10_000_000:
            raise ValueError(f"invalid message length: {length}")

        print(length_buf)

        data_buf = b''
        while len(data_buf) < length:
            chunk = self.sock.recv(length - len(data_buf))
            if not chunk:
                raise IOError("socket closed during message read")
            data_buf += chunk

        print(data_buf)

        envelope_json = json.loads(data_buf)
        print(repr(envelope_json))
        if not isinstance(envelope_json, dict) or 'type' not in envelope_json or 'data' not in envelope_json:
            raise ValueError("malformed envelope")

        if envelope_json['type'] != cls.__name__:
            raise ValueError(f"Envelope type mismatch: expected {cls.__name__}, got {envelope_json['type']}")

        base64_data = envelope_json['data']
        decoded_bytes = base64.b64decode(base64_data)
        inner_data = json.loads(decoded_bytes)
        if not isinstance(inner_data, dict):
            raise ValueError("inner data is not a dict")

        return cls(**inner_data)
    
    def emit(self, message: object, *, is_response: bool = False, id: str = ""):
        # length prefix has to be 4 bytes big
        type_name = type(message).__name__
        encoded_data = base64.b64encode(json.dumps(message.__dict__).encode()).decode()

        envelope = {
            "type": type_name,
            "id": id or "client-generated-id",
            "data": encoded_data,
            "isResponse": is_response
        }

        raw = json.dumps(envelope).encode()
        # b'\x00\x00\x00b'
        length_prefix = struct.pack('>I', len(raw))
        print(length_prefix + raw)
        # this isnt right fix it
        print(f"sent {repr(envelope)}")
        self.sock.sendall(length_prefix + raw)

@dataclass
class Test:
    msg: str

path = "/tmp/corndeliveryutility/serv.sock"

socket = SocketClient(path)

msg = socket.recieve(Test)

print(f"received: {repr(msg)}")

socket.emit(Test(msg="bow"))
