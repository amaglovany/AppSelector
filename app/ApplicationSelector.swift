//
//  ApplicationSelector.swift
//  app
//
//  Created by Artem Maglyovany on 8/7/19.
//  Copyright © 2019 com.amaglovany.selector. All rights reserved.
//

import UIKit

public enum Schema {
    
    case mail(to: String)
    case tel(to: String)
    case geo(address: String)
    
    var ordinal: Int {
        switch self {
        case .mail(_): return 0
        case .tel(_): return 1
        case .geo(_): return 2
        }
    }
    
    var value: String {
        switch self {
        case .mail(let recipient): return recipient
        case .tel(let phone): return phone
        case .geo(let address): return address
        }
    }
}

public class ApplicationSelector {
    
    public static let shared = ApplicationSelector(
        openWith: "Open With", cancel: "Cancel",
        mail: [
            SelectingApplication(name: "Gmail", baseUrl: "googlegmail://") { "co?to=\($0)" },
            SelectingApplication(name: "Outlook", baseUrl: "ms-outlook://") { "compose?to=\($0)" },
            SelectingApplication(name: "Mail", baseUrl: "mailto://")
        ],
        tel: [
            SelectingApplication(name: "Phone", baseUrl: "tel://")
        ],
        geo: [
            SelectingApplication(name: "Google Maps", baseUrl: "comgooglemaps://") { "?q=" + $0.encodedUrlQuery },
            SelectingApplication(name: "Waze", baseUrl: "waze://") { "ul?q=" + $0.encodedUrlQuery },
            SelectingApplication(name: "Apple Maps", baseUrl: "http://maps.apple.com/") { "?q=" + $0.encodedUrlQuery }
        ]
    )
    
    private let applications: [Int: [SelectingApplication]]
    
    private let openWith: String
    private let cancel: String
    
    fileprivate init(
        openWith: String, cancel: String,
        mail: [SelectingApplication] = [],
        tel: [SelectingApplication] = [],
        geo: [SelectingApplication] = []) {
        self.openWith = openWith
        self.cancel = cancel
        self.applications = [0: mail, 1: tel, 2: geo]
    }
    
    func open(_ schema: Schema) {
        guard
            let controller = UIApplication.shared.currentController,
            let apps = applications[schema.ordinal]
            else { return }
        
        let value = schema.value
        let actions = apps
            .filter { $0.installed() }
            .map { _UIAlertAction($0, value: value) }
        
        guard actions.count > 1 else {
            let action = actions.first!
            action.handler?(action)
            return
        }
        
        let ac = UIAlertController(title: openWith, message: nil, preferredStyle: .actionSheet)
        for action in actions {
            ac.addAction(action)
        }
        
        ac.addAction(_UIAlertAction(title: cancel, style: .cancel, handler: nil))
        
        DispatchQueue.main.async {
            controller.present(ac, animated: true)
        }
    }
    
}

// MARK: -
public class SelectingApplication {
    public typealias Transformation = (_ value: String) -> String
    
    let applicationName: String
    
    private let baseUrl: String
    private let transformation: Transformation
    private let url: URL
    
    public init(name: String, baseUrl: String, transformation: @escaping Transformation = { $0 }) {
        self.applicationName = name
        self.baseUrl = baseUrl
        self.transformation = transformation
        self.url = URL(string: baseUrl)!
    }
    
    func installed() -> Bool {
        return UIApplication.shared.canOpenURL(url)
    }
    
    func transform(_ value: String) -> String {
        return baseUrl + transformation(value)
    }
    
}

// MARK: - Internal extension -

private extension String {
    
    var encodedUrlQuery: String {
        return addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    }
    
}

private final class _UIAlertAction: UIAlertAction {
    
    var handler: ((UIAlertAction) -> Void)? = nil
    
    convenience init(_ application: SelectingApplication, value: String) {
        let url = URL(string: application.transform(value))!
        let handler: ((UIAlertAction) -> Void) = { _ in
            let shared = UIApplication.shared
            guard shared.canOpenURL(url) else { return }
            
            if #available(iOS 10, *) {
                shared.open(url)
            } else {
                shared.openURL(url)
            }
        }
        
        self.init(title: application.applicationName, style: .default, handler: handler)
        self.handler = handler
    }
}

private extension UIAlertController {
    convenience init(title: String? = nil, message: String? = nil, style: UIAlertController.Style = .alert) {
        self.init(title: title, message: message, preferredStyle: style)
    }
}

private extension UIApplication {
    var currentController: UIViewController? {
        if var controller = UIApplication.shared.keyWindow?.rootViewController {
            while let presented = controller.presentedViewController {
                controller = presented
            }
            
            return controller
        }
        
        return nil
    }
}
