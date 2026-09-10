import SwiftUI
import WidgetKit

/// Everything Nasar Flow shows outside its own screens: the "Flow is on" Live
/// Activity (Dynamic Island + Lock Screen banner), a Lock Screen / Home Screen
/// widget that opens Quick Dictate, and on iOS 18 the Control Center controls.
/// Each is a separate extension entry point, but one bundle, one target, one
/// provisioning profile ("Nasar Flow Widgets" - see README).
@main
struct NasarFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlowLiveActivity()
        DictateWidget()
        if #available(iOS 18.0, *) {
            DictateControl()
            FlowControl()
        }
    }
}
