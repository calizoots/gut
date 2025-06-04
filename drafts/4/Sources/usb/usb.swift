import Foundation
import DiskArbitration
import Cocoa
import IOKit
import IOKit.storage

struct USBIcon {
    let bundleid: String
    let resfile: String
}

struct USBDevice {
    let attrname: String = "straight.fucking.bine"
    let name: String
    let serial: String
    let vendor: String
    let icon: USBIcon
    let volumetype: String 
    let volumepath: URL
    let capacity: Int

    func print(_ log: Logger) {
        log.print(.info, "Device serial number \(serial)")
        let gb = Double(capacity) / (1024.0 * 1024.0 * 1024.0)
        let mb = Double(capacity) / (1024.0 * 1024.0)
        log.print(.info, "Capacity \(String(format: "%.0f", mb)) megabytes")
        log.print(.info, "Capacity \(String(format: "%.2f", gb)) gigabytes")
        log.print(.info, "Device name \(name)")
        log.print(.info, "Device vendor \(vendor)")
        log.print(.info, "Volume type \(volumetype)")
        log.print(.info, "Volume path \(volumepath.path)")
    }

    func GetSecretMessage() throws -> String {
        var passPath = volumepath
        passPath.append(path: ".meta")

        let size = getxattr(passPath.path, attrname, nil, 0, 0, 0)

        if size >= 0 {
            var buffer = [UInt8](repeating: 0, count: size)
            let read = getxattr(passPath.path, attrname, &buffer, size, 0, 0)

            if read >= 0 {
                let readData = Data(buffer)

                guard let dataString = String(data: readData, encoding: .utf8) else {
                    throw RuntimeError("failed to convert data to string")
                }

                return dataString
            } else {
                throw RuntimeError("getxattr failed")
            }
        } else {
            throw RuntimeError("getxattr size check failed")
        }
    }

    func SetSecretMessage(data: String) throws -> Int {
        var encfilepath = self.volumepath
        encfilepath.append(path: ".meta")
    
        if !FileManager.default.fileExists(atPath: encfilepath.path) {
            FileManager.default.createFile(atPath: encfilepath.path, contents: nil, attributes: nil)

            do {
                try "do not fucking touch please thank you <3".data(using: .utf8)!.write(to: encfilepath) 
            } catch {
                Swift.print("unexpected error: ", error)
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
                    let vendor = (dict as NSDictionary)["DADeviceVendor"] as? String ?? "--"
                    let driveCapacity = (dict as NSDictionary)["DAMediaSize"] as? Int ?? 0
                    let name = (dict as NSDictionary)["DAVolumeName"] as? String ?? "--"
                    let voltype = (dict as NSDictionary)["DAVolumeType"] as? String ?? "--"
                    if let volpath = (dict as NSDictionary)["DAVolumePath"] as? URL {
                        if let iconInfo = (dict as NSDictionary)["DAMediaIcon"] as? NSDictionary {
                            if let bundleID = iconInfo["CFBundleIdentifier"] as? String, let resourceFile = iconInfo["IOBundleResourceFile"] as? String {
                                return USBDevice(
                                    name: name, 
                                    serial: String(describing: sSerial), 
                                    vendor: vendor, 
                                    icon: USBIcon(bundleid: bundleID, resfile: resourceFile),
                                    volumetype: voltype, 
                                    volumepath: volpath, 
                                    capacity: driveCapacity
                                )
                            }
                        }
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

    func RefreshUSBList() {
        let allMountedURLIncludingDMG = self.FindRemovableVolumes()  

        var usbs: [USBDevice] = []

        for url in allMountedURLIncludingDMG {
            if let thing = self.GetSerialAndSize(url) {
                usbs.append(thing)
            }
        }

        self.usbDevices = usbs
    }

    init() {
        RefreshUSBList()
    }
}
