import Foundation
import DiskArbitration
import IOKit
import IOKit.storage

struct USBDevice {
    let name: String
    let serial: String
    let vendor: String
    let volumetype: String 
    let volumepath: URL
    let capacity: Int

    func prnt() {
        print("Device serial number", self.serial)
        let gb = Double(self.capacity) / (1024.0 * 1024.0 * 1024.0)
        let mb = Double(self.capacity) / (1024.0 * 1024.0)
        print("Capacity", String(format: "%.0f", mb), "megabytes")
        print("Capacity", String(format: "%.2f", gb), "gigabytes")
        print("Device name", self.name)
        print("Device vendor", self.vendor)
        print("Volume type", self.volumetype)
        print("Volume path", self.volumepath.path())
    }
}

class USB {
    var usbDevices: [USBDevice] = []

    func GetSerialAndSize(_ url: URL) -> USBDevice? {
        if let session = DASessionCreate(nil) {
            if let disk : DADisk = DADiskCreateFromVolumePath(nil, session, url as CFURL) {
                let ioService : io_service_t = DADiskCopyIOMedia(disk)
                    let key = "USB Serial Number"

                    let options : IOOptionBits = IOOptionBits(kIORegistryIterateParents) |
                    IOOptionBits(kIORegistryIterateRecursively)

                    if let sSerial : CFTypeRef = IORegistryEntrySearchCFProperty(ioService, kIOServicePlane, key as CFString, nil, options) {
                        let dict: CFDictionary = DADiskCopyDescription(disk)!
                            // print(dict)
                            let vendor = (dict as NSDictionary)["DADeviceVendor"] as? String ?? "--"
                            let driveCapacity = (dict as NSDictionary)["DAMediaSize"] as? Int ?? 0
                            let name = (dict as NSDictionary)["DAVolumeName"] as? String ?? "--"
                            let voltype = (dict as NSDictionary)["DAVolumeType"] as? String ?? "--"
                            if let volpath = (dict as NSDictionary)["DAVolumePath"] as? URL {
                                return USBDevice(
                                    name: name, 
                                    serial: String(describing: sSerial), 
                                    vendor: vendor, 
                                    volumetype: voltype, 
                                    volumepath: volpath, 
                                    capacity: driveCapacity
                                )
                            }
                    } else {
                        return nil
                    }
            }
        }
        return nil
    }

    func FindRemovableVolumes() -> [URL] {
    	var allMountedURL = [URL]()
    	let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
    	let paths = FileManager().mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [])
    	if let urls = paths {
    	    for url in urls {
    	        let components = url.pathComponents
    	        if components.count > 1 && components[1] == "Volumes" {
    	            allMountedURL.append(url)
    	        }
    	    }
    	}
    	return allMountedURL
    }

    func SetSecretMessage(_ drive: USBDevice, _ attrname: String, _ data: String) throws -> Int {
        var encfilepath = drive.volumepath
        encfilepath.append(path: ".meta")
    
        if !FileManager.default.fileExists(atPath: encfilepath.path) {
            FileManager.default.createFile(atPath: encfilepath.path, contents: nil, attributes: nil)
            do {
                try "do not fucking touch please thank you <3".data(using: .utf8)!.write(to: encfilepath) 
            } catch {
                print("unexpected error: ", error)
                return 0
            }
        }
    
        guard let dataBytes = data.data(using: .utf8) else {
            throw RuntimeError("failed to convert string to data")
        }
    
        let res = dataBytes.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int32 in
            return setxattr(encfilepath.path, attrname, ptr.baseAddress, data.count, 0, 0)
        }
    
        if res == 0 {
            return data.count
        } else {
            throw RuntimeError("xattr failed")
        }
    }
    
    func GetSecretMessage(_ drive: USBDevice, _ attrname: String) throws -> String? {
        var encfilepath = drive.volumepath
        encfilepath.append(path: ".meta")
        let size = getxattr(encfilepath.path, attrname, nil, 0, 0, 0)
        if size >= 0 {
            var buffer = [UInt8](repeating: 0, count: size)
            let read = getxattr(encfilepath.path, attrname, &buffer, size, 0, 0)
            if read >= 0 {
                let readData = Data(buffer)
                guard let dataString = String(data: readData, encoding: .utf8) else {
                    print("failed to convert data to string")
                    return nil
                }
                return dataString
            } else {
                throw RuntimeError("getxattr failed")
            }
        } else {
            throw RuntimeError("getxattr size check failed")
        }
    }

    init() throws {
        let allMountedURLIncludingDMG = self.FindRemovableVolumes()  
        var usbs: [USBDevice] = []
        for url in allMountedURLIncludingDMG {
            if let thing = self.GetSerialAndSize(url) {
                usbs.append(thing)
            }
        }

        if usbs.isEmpty {
            throw RuntimeError("no usb devices connected")
        }

        self.usbDevices = usbs
    }
}
