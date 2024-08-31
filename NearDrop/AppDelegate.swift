//
//  AppDelegate.swift
//  NearDrop
//
//  Created by Grishka on 08.04.2023.
//

import Cocoa
import UserNotifications
import NearbyShare

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, MainAppDelegate {
	private var statusItem:NSStatusItem?
	private var activeIncomingTransfers:[String:TransferInfo] = [:]
	private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? NSLocalizedString("AboutAlert.UnknownVersion", value: "(unknown)", comment: "")

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		let menu = NSMenu()
		
		menu.addItem(withTitle: NSLocalizedString("VisibleToEveryone", value: "Visible to everyone", comment: ""), action: nil, keyEquivalent: "")
		menu.addItem(withTitle: String(format: NSLocalizedString("DeviceName", value: "Device name: %@", comment: ""), arguments: [Host.current().localizedName!]), action: nil, keyEquivalent: "")
		
		menu.addItem(NSMenuItem.separator())
		let copyToClipboardItem = menu.addItem(withTitle: NSLocalizedString("AutoCopyToClipboard", value: "Copy texts to clipboard automatically", comment: ""), action: #selector(toggleOption(_:)), keyEquivalent: "")
		copyToClipboardItem.state = Preferences.autoCopyToClipboard ? .on : .off
		copyToClipboardItem.tag = .autoCopyToClipboard
		let openLinksItem = menu.addItem(withTitle: NSLocalizedString("OpenLinksInApp", value: "Open links in default applications", comment: ""), action: #selector(toggleOption(_:)), keyEquivalent: "")
		openLinksItem.state = Preferences.openLinksInApp ? .on : .off
		openLinksItem.tag = .openLinksInApp
		
		menu.addItem(NSMenuItem.separator())
		menu.addItem(withTitle: String(format: NSLocalizedString("About", value: "About NearDropPlusPlus %@", comment: ""), arguments: [AppDelegate.appVersion]), action: #selector(self.showAboutAlert), keyEquivalent: "")
		menu.addItem(withTitle: NSLocalizedString("Quit", value: "Quit NearDropPlusPlus", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
		
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		statusItem?.button?.image = NSImage(named: "MenuBarIcon")
		statusItem?.button?.toolTip = Bundle.main.infoDictionary?["CFBundleName"] as? String
		statusItem?.menu = menu
		statusItem?.behavior = .removalAllowed
		
		let nc = UNUserNotificationCenter.current()
		nc.requestAuthorization(options: [.alert, .sound]) { granted, err in
			if !granted {
				DispatchQueue.main.async {
					self.showNotificationsDeniedAlert()
				}
			}
		}
		nc.delegate = self
		let incomingTransfersCategory = UNNotificationCategory(identifier: "INCOMING_TRANSFERS", actions: [
			UNNotificationAction(identifier: "ACCEPT", title: NSLocalizedString("Accept", comment: ""), options: UNNotificationActionOptions.authenticationRequired),
			UNNotificationAction(identifier: "DECLINE", title: NSLocalizedString("Decline", comment: ""))
		], intentIdentifiers: [])
		let errorsCategory = UNNotificationCategory(identifier: "ERRORS", actions: [], intentIdentifiers: [])
		nc.setNotificationCategories([incomingTransfersCategory, errorsCategory])
		NearbyConnectionManager.shared.mainAppDelegate = self
		NearbyConnectionManager.shared.becomeVisible()
	}
	
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		statusItem?.isVisible = true
		return true
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		UNUserNotificationCenter.current().removeAllDeliveredNotifications()
	}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
    
	@objc func showAboutAlert() {
		let alert = NSAlert()

		alert.messageText = String(format: NSLocalizedString("AboutAlert.Title", value: "NearDropPlusPlus v%@", comment: ""), arguments: [AppDelegate.appVersion])
		
		alert.informativeText = "\n" + NSLocalizedString("AboutAlert.Credit", value: "From NearDrop by grishka", comment: "")
		
		alert.addButton(withTitle: NSLocalizedString("OK", value: "OK", comment: ""))
		alert.runModal()
	}
	
	@objc func toggleOption(_ sender: NSMenuItem) {
		let shouldBeOn = sender.state != .on
		sender.state = shouldBeOn ? .on : .off
		switch sender.tag {
		case .autoCopyToClipboard:
			Preferences.autoCopyToClipboard = shouldBeOn
		case .openLinksInApp:
			Preferences.openLinksInApp = shouldBeOn
		default:
			print("Unhandled toggle menu action")
		}
	}

	
	func showNotificationsDeniedAlert() {
		let alert = NSAlert()
		alert.alertStyle = .critical
		alert.messageText = NSLocalizedString("NotificationsDenied.Title", value: "Notification Permission Required", comment: "")
		alert.informativeText = NSLocalizedString("NotificationsDenied.Message", value: "NearDrop needs to be able to display notifications for incoming file transfers. Please allow notifications in System Settings.", comment: "")
		alert.addButton(withTitle: NSLocalizedString("NotificationsDenied.OpenSettings", value: "Open settings", comment: ""))
		alert.addButton(withTitle: NSLocalizedString("Quit", value: "Quit NearDrop", comment: ""))
		let result = alert.runModal()
		if result == NSApplication.ModalResponse.alertFirstButtonReturn {
			NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
		} else if result == NSApplication.ModalResponse.alertSecondButtonReturn {
			NSApplication.shared.terminate(nil)
		}
	}
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		let transferID = response.notification.request.content.userInfo["transferID"]! as! String
        NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: response.actionIdentifier == "ACCEPT")
		if response.actionIdentifier != "ACCEPT" {
			activeIncomingTransfers.removeValue(forKey: transferID)
		}
		completionHandler()
	}
	
	func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
		let fileStr:String
		if let textTitle = transfer.textDescription {
			fileStr = textTitle
		} else if transfer.files.count == 1 {
			fileStr = transfer.files[0].name
		} else {
			fileStr = String.localizedStringWithFormat(NSLocalizedString("NFiles", value: "%d files", comment: ""), transfer.files.count)
		}
		let notificationContent = UNMutableNotificationContent()
		notificationContent.title = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "NearDropPlusPlus"
		notificationContent.subtitle = String(format:NSLocalizedString("PinCode", value: "PIN: %@", comment: ""), arguments: [transfer.pinCode!])
		notificationContent.body = String(format: NSLocalizedString("DeviceSendingFiles", value: "%1$@ is sending you %2$@", comment: ""), arguments: [device.name, fileStr])
		notificationContent.sound = .default
		notificationContent.categoryIdentifier = "INCOMING_TRANSFERS"
		notificationContent.userInfo = ["transferID": transfer.id]
		if #available(macOS 11.0, *) {
			NDNotificationCenterHackery.removeDefaultAction(notificationContent)
		}
		let notificationReq = UNNotificationRequest(identifier: "transfer_"+transfer.id, content: notificationContent, trigger: nil)
		UNUserNotificationCenter.current().add(notificationReq)
		self.activeIncomingTransfers[transfer.id] = TransferInfo(device: device, transfer: transfer)
	}
	
	func incomingTransfer(id: String, didFinishWith error: Error?) {
		guard let transfer = self.activeIncomingTransfers[id] else { return }
		if let error = error {
			let notificationContent = UNMutableNotificationContent()
			notificationContent.title = String(format: NSLocalizedString("TransferError", value: "Failed to receive files from %@", comment: ""), arguments: [transfer.device.name])
			if let ne = (error as? NearbyError) {
				switch ne {
				case .inputOutput:
					notificationContent.body = "I/O Error";
				case .protocolError(_):
					notificationContent.body = NSLocalizedString("Error.Protocol", value: "Communication error", comment: "")
				case .requiredFieldMissing:
					notificationContent.body = NSLocalizedString("Error.Protocol", value: "Communication error", comment: "")
				case .ukey2:
					notificationContent.body = NSLocalizedString("Error.Crypto", value: "Encryption error", comment: "")
				case .canceled(reason: _):
					break; // can't happen for incoming transfers
				}
			} else {
				notificationContent.body = error.localizedDescription
			}
			notificationContent.categoryIdentifier = "ERRORS"
			UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "transferError_"+id, content: notificationContent, trigger: nil))
		}
		UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["transfer_"+id])
		self.activeIncomingTransfers.removeValue(forKey: id)
	}
	
	func incomingTransferAcceptedAlert(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
		let fileStr:String
		if let textTitle = transfer.textDescription {
			fileStr = textTitle
		} else if transfer.files.count == 1 {
			fileStr = transfer.files[0].name
		} else {
			fileStr = String.localizedStringWithFormat(NSLocalizedString("NFiles", value: "%d files", comment: ""), transfer.files.count)
		}
		
		let notificationContent = UNMutableNotificationContent()
		notificationContent.title = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "NearDropPlusPlus"
		notificationContent.subtitle = "Incoming Transfer Accepted"
		if transfer.textDescription == nil {
			notificationContent.body = fileStr + " from " + device.name + " saved in Downloads folder."
		} else {
			notificationContent.body = "Content from " + device.name
			notificationContent.body += Preferences.openLinksInApp ? " opened in default browser." : " pasted in clipboard."
		}
		notificationContent.categoryIdentifier = "INCOMING_TRANSFERS"
		notificationContent.userInfo = ["transferID": transfer.id]
		notificationContent.categoryIdentifier = "ERRORS"
		UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "transferAccepted_"+transfer.id, content: notificationContent, trigger: nil))
	}
}

struct TransferInfo {
	let device:RemoteDeviceInfo
	let transfer:TransferMetadata
}

// MARK: - Menu item tags
fileprivate extension Int {
	static let autoCopyToClipboard = 1
	static let openLinksInApp = 2
}
