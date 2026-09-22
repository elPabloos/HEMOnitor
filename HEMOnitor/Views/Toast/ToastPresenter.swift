//
//  ToastPresenter.swift
//  HEMOnitor
//

import Foundation
import SwiftUI

enum ToastKind {
    case success, error, info

    var iconSystemName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return AppColor.zoneWellCovered
        case .error: return AppColor.dangerForeground
        case .info: return AppColor.primaryGreen
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let kind: ToastKind
    let message: String

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// A simple presenter for short toasts (confirmations/errors), consumed via
/// `.toastHost(_:)`. Any view that needs to show toasts creates its own
/// `@StateObject` and attaches it to the root screen of that flow.
@MainActor
final class ToastPresenter: ObservableObject {
    @Published private(set) var current: Toast?

    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, kind: ToastKind = .info, duration: TimeInterval = 2.6) {
        dismissTask?.cancel()
        let toast = Toast(kind: kind, message: message)
        current = toast
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, self.current?.id == toast.id else { return }
            self.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}
