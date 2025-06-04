import Foundation
import AppKit

@MainActor
func showInsertKey(vol: Volume, usb: USB, volmngr: VolumeManager) async {
    NSApp.activate(ignoringOtherApps: true)
    let width: CGFloat = 200
    let height: CGFloat = 150
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.titled, .borderless],
        backing: .buffered,
        defer: false
    )

    window.level = .modalPanel
    window.isReleasedWhenClosed = false

    if let screen = NSScreen.main {
        let screenRect = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: screenRect.minX + 10, y: screenRect.maxY + height))
    }

    // window.center()

    window.title = "🔐"
    // window.backgroundColor = .black
    
    let contentView = NSView(frame: window.contentView!.bounds)
    contentView.autoresizingMask = [.width, .height]

    // place this in center regardless of height
    let label = NSTextField(labelWithString: "insert usb key")
    label.font = NSFont.systemFont(ofSize: 16)
    label.alignment = .center
    label.sizeToFit()
    label.frame = NSRect(
        x: (width - label.frame.width) / 2,
        y: ((height - label.frame.height) / 2) + 5,
        width: label.frame.width,
        height: label.frame.height
    )
    contentView.addSubview(label)

    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    while true {
        do {
            usb.RefreshUSBList()
            let _ = try vol.mount(password: try volmngr.getPassword())
            break
        } catch {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    window.close()
}

class USBPickerWinContr: NSWindowController, NSWindowDelegate {
    let title: String
    var radioButtons: [NSButton] = []
    var usbDevices: [USBDevice] = []

    init(usbDevices: [USBDevice], title: String) {
        self.title = title
        self.usbDevices = usbDevices
        super.init(window: nil)
        setupWindow()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.title = title
        self.window = window

        window.center()

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for (index, device) in usbDevices.enumerated() {
            let itemStack = NSStackView()
            itemStack.orientation = .horizontal
            itemStack.spacing = 10
            itemStack.alignment = .centerY

            let iconImageView = NSImageView()
            iconImageView.image = NSImage(contentsOfFile:
                Bundle(identifier: device.icon.bundleid)?
                    .path(forResource: device.icon.resfile, ofType: nil) ?? ""
            ) ?? NSWorkspace.shared.icon(forFile: device.volumepath.path)
            iconImageView.setFrameSize(NSSize(width: 48, height: 48))

            let radioButton = NSButton(radioButtonWithTitle: device.name, target: self, action: #selector(radioButtonClicked(_:)))
            radioButton.tag = index
            radioButtons.append(radioButton)

            let info = """
            Vendor: \(device.vendor)
            Serial: \(device.serial)
            Type: \(device.volumetype)
            Path: \(device.volumepath.path)
            Capacity: \(String(format: "%.2f", Double(device.capacity) / (1024*1024*1024))) GB
            """

            let infoLabel = NSTextField(labelWithString: info)
            infoLabel.font = NSFont.systemFont(ofSize: 11)
            infoLabel.lineBreakMode = .byWordWrapping
            infoLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let subStack = NSStackView(views: [radioButton, iconImageView, infoLabel])
            subStack.spacing = 10
            subStack.alignment = .centerY
            subStack.translatesAutoresizingMaskIntoConstraints = false

            stackView.addArrangedSubview(subStack)        
        }

        contentView.addSubview(stackView)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    @objc func radioButtonClicked(_ sender: NSButton) {
        for button in radioButtons {
            button.state = (button == sender) ? .on : .off
        }
    }
}

@MainActor
func pickUSBUI(_ usb: USB, title: String) async throws -> USBDevice? {
    guard !usb.usbDevices.isEmpty else {
        throw KeyError.noUSBInserted
    }

    let picker = USBPickerWinContr(usbDevices: usb.usbDevices, title: title)
    picker.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)

    var selectedDevice: USBDevice?

    while true {
        if let selected = picker.radioButtons.first(where: { $0.state == .on }) {
            selectedDevice = usb.usbDevices[selected.tag]
            NSApplication.shared.stop(nil)
            break
        }

        if picker.window?.isVisible == false {
            NSApplication.shared.stop(nil)
            break
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    picker.close()

    if let device = selectedDevice {
        return device
    } else {
        return nil
    }
}
