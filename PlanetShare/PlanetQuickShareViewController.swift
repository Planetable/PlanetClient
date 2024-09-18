//
//  PlanetQuickShareViewController.swift`
//  PlanetShare
//

import UIKit
import Social

class PlanetQuickShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let context = self.extensionContext else {
            return
        }
        debugPrint("context: \(context), input items count: \(context.inputItems.count)")
        guard let item = context.inputItems.first as? NSExtensionItem else {
            return
        }
        debugPrint("first input item: \(item), attachments count: \(item.attachments?.count ?? 0)")
        guard let itemProvider = item.attachments?.first as? NSItemProvider else {
            return
        }
        debugPrint("first provider attachment: \(itemProvider)")
    }

    override func isContentValid() -> Bool {
        guard isTargetPlanetAvailable() else { return false }
        return true
    }

    override func didSelectPost() {
        debugPrint("did select post")
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    
    // MARK: TODO: Handle active planet and posting content here.
    // MARK: -
    
    private func isTargetPlanetAvailable() -> Bool {
        return false
    }
    
    private func postToTargetPlanet() {
        
    }
}
