import SwiftUI

/// A compact native preference row. Long explanations are available on demand.
struct VocaPreferenceRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    @State private var showDetail = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.title).font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                if self.detail.count <= 85 {
                    Text(self.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if self.detail.count > 85 {
                Button("About \(self.title)", systemImage: "info.circle") { self.showDetail.toggle() }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary)
                    .popover(isPresented: self.$showDetail) {
                        Text(self.detail).font(.callout).fixedSize(horizontal: false, vertical: true).padding(16).frame(width: 280)
                    }
            }
            Toggle(self.title, isOn: self.$isOn).toggleStyle(.switch).labelsHidden()
        }.padding(.vertical, 3)
    }
}

struct VocaSettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { self.content.frame(maxWidth: .infinity, alignment: .leading).vocaContentSurface() }
}

struct VocaSettingsDisclosure<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.settingsSearchPresentation) private var search
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(self.title, isExpanded: self.$expanded) {
            self.content.padding(.top, 14)
        }.font(.callout.weight(.medium))
            .onAppear { if self.search != nil { self.expanded = true } }
            .onChange(of: self.search?.primaryTarget) { _, target in if target != nil { self.expanded = true } }
    }
}
