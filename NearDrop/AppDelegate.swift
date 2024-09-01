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
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		statusItem?.button?.image = NSImage(named: "MenuBarIcon")
		statusItem?.button?.toolTip = Bundle.main.infoDictionary?["CFBundleName"] as? String
		statusItem?.behavior = .removalAllowed
		updateMenu()
		
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
			UNNotificationAction(identifier: "ACCEPTANDREMEMBER", title: NSLocalizedString("AcceptAndRemember", comment: ""), options: UNNotificationActionOptions.authenticationRequired),
			UNNotificationAction(identifier: "DECLINE", title: NSLocalizedString("Decline", comment: ""))
		], intentIdentifiers: [])
		let errorsCategory = UNNotificationCategory(identifier: "ERRORS", actions: [], intentIdentifiers: [])
		nc.setNotificationCategories([incomingTransfersCategory, errorsCategory])
		NearbyConnectionManager.shared.mainAppDelegate = self
		NearbyConnectionManager.shared.becomeVisible()
	}
	
	func updateMenu() {
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
		if !Preferences.rememberedDevices.isEmpty {
			menu.addItem(withTitle: NSLocalizedString("RememberedDevices", value: "Remembered devices (click to remove)", comment: ""), action: nil, keyEquivalent: "")
		} else {
			menu.addItem(withTitle: NSLocalizedString("NoRememberedDevices", value: "No remembered device", comment: ""), action: nil, keyEquivalent: "")
		}
		for deviceName in Preferences.rememberedDevices {
			let menuItem = NSMenuItem(title: deviceName, action: #selector(removeDevice(_:)), keyEquivalent: "")
			menuItem.target = self
			menu.addItem(menuItem)
		}
		
		menu.addItem(NSMenuItem.separator())
		menu.addItem(withTitle: String(format: NSLocalizedString("About", value: "About NearDropPlusPlus %@", comment: ""), arguments: [AppDelegate.appVersion]), action: #selector(self.showAboutAlert), keyEquivalent: "")
		menu.addItem(withTitle: NSLocalizedString("Quit", value: "Quit NearDropPlusPlus", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
		
		statusItem?.menu = menu
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
	
	@objc func removeDevice(_ sender: NSMenuItem) {
		if let index = Preferences.rememberedDevices.firstIndex(of: sender.title) {
			Preferences.rememberedDevices.remove(at: index)
			updateMenu()
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
		NearbyConnectionManager.shared.submitUserConsent(transferID: transferID,
																										 accept: response.actionIdentifier == "ACCEPT" || response.actionIdentifier == "ACCEPTANDREMEMBER",
																										 rememberDevice: response.actionIdentifier == "ACCEPTANDREMEMBER")
		if (response.actionIdentifier != "ACCEPT" && response.actionIdentifier != "ACCEPTANDREMEMBER") {
			activeIncomingTransfers.removeValue(forKey: transferID)
		}
		completionHandler()
	}
	
	func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
		if Preferences.rememberedDevices.contains(device.name) ||
				(Preferences.autoCopyToClipboard && transfer.textDescription != nil) {
			NearbyConnectionManager.shared.submitUserConsent(transferID: transfer.id, accept: true, rememberDevice: false)
		} else {
			let fileStr:String
			if let textTitle = transfer.textDescription {
				fileStr = textTitle
			} else if transfer.files.count == 1 {
				fileStr = transfer.files[0].name
			} else {
				fileStr = NSString.localizedUserNotificationString(forKey: "NFiles", arguments: [transfer.files.count])
			}
			let notificationContent = UNMutableNotificationContent()
			notificationContent.title = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "NearDropPlusPlus"
			notificationContent.subtitle = NSString.localizedUserNotificationString(forKey: "PinCode", arguments: [transfer.pinCode!])
			notificationContent.body = NSString.localizedUserNotificationString(forKey: "DeviceSendingFiles", arguments: [device.name, fileStr])
			notificationContent.sound = .default
			notificationContent.categoryIdentifier = "INCOMING_TRANSFERS"
			notificationContent.userInfo = ["transferID": transfer.id]
			if #available(macOS 11.0, *) {
				NDNotificationCenterHackery.removeDefaultAction(notificationContent)
			}
			let notificationReq = UNNotificationRequest(identifier: "transfer_"+transfer.id, content: notificationContent, trigger: nil)
			UNUserNotificationCenter.current().add(notificationReq)
		}
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
					notificationContent.body = NSString.localizedUserNotificationString(forKey: "TransferError.IO", arguments: [])
				case .protocolError(_):
					notificationContent.body = NSString.localizedUserNotificationString(forKey: "TransferError.Protocol", arguments: [])
				case .requiredFieldMissing:
					notificationContent.body = NSString.localizedUserNotificationString(forKey: "TransferError.Protocol", arguments: [])
				case .ukey2:
					notificationContent.body = NSString.localizedUserNotificationString(forKey: "TransferError.Crypto", arguments: [])
				case .canceled(reason: _):
					break; // can't happen for incoming transfers
				}
			} else {
				notificationContent.body = error.localizedDescription
			}
			notificationContent.categoryIdentifier = "ERRORS"
			UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "transferError_"+id, content: notificationContent, trigger: nil))
		} else {
			let fileStr:String
			if transfer.transfer.textDescription != nil {
				fileStr = NSString.localizedUserNotificationString(forKey: "Texts", arguments: [])
			} else if transfer.transfer.files.count == 1 {
				fileStr = transfer.transfer.files[0].name
			} else {
				fileStr = NSString.localizedUserNotificationString(forKey: "NFiles", arguments: [transfer.transfer.files.count])
			}
			let notificationContent = UNMutableNotificationContent()
			notificationContent.title = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "NearDropPlusPlus"
			notificationContent.subtitle = NSString.localizedUserNotificationString(forKey: "TransferAccepted", arguments: [fileStr, transfer.device.name])
			if transfer.transfer.textDescription == nil {
				notificationContent.body = NSString.localizedUserNotificationString(forKey: "TransferAccepted.Files", arguments: [])
			} else {
				notificationContent.body = NSString.localizedUserNotificationString(forKey: "TransferAccepted.Texts", arguments: [(Preferences.autoCopyToClipboard || !Preferences.openLinksInApp) ?
								NSString.localizedUserNotificationString(forKey: "TransferAccepted.Texts.Copy", arguments: []) :
								NSString.localizedUserNotificationString(forKey: "TransferAccepted.Texts.Open", arguments: [])])
			}
			notificationContent.categoryIdentifier = "INCOMING_TRANSFERS_COMPLETED"
			notificationContent.userInfo = ["transferID": transfer.transfer.id]
			UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "transferCompleted_"+transfer.transfer.id, content: notificationContent, trigger: nil))
		}
		UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["transfer_"+id])
		self.activeIncomingTransfers.removeValue(forKey: id)
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
