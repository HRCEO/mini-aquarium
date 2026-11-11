import MiniAquariumCore
import SwiftUI

/// 어항 탭의 시스템 상태 연동 스위치. 기본은 꺼져 있어 그냥 구경만 할 수 있다.
struct SystemLinkControls: View {
    @ObservedObject var model: AquariumModel

    var body: some View {
        Section(tr("시스템 상태 연동", "System link")) {
            ToggleRow(title: tr("Mac 상태를 어항에 반영", "Reflect Mac status in the tank"), isOn: model.settings.systemLink) { isOn in
                model.update { $0.with(systemLink: isOn) }
            }
            Text(model.settings.systemLink
                 ? tr("CPU가 바쁘면 물고기가 빨리 헤엄치고, 배터리가 줄면 물이 낮아져요(충전 중엔 가득). 메모리가 많이 차면 물이 흐려져요.",
                      "Busy CPU makes fish swim faster, a low battery lowers the water (full while charging), and high memory use clouds it.")
                 : tr("꺼 두면 어항은 평소 모습 그대로예요.", "When off, the tank looks the same as usual."))
                .font(.caption).foregroundStyle(.secondary)
            if model.settings.systemLink {
                SystemStatusRows(load: model.systemLoad)
            }
        }
    }
}

/// 지금 읽은 Mac 상태와, 그것이 어항에 어떻게 반영되는지 한눈에 보여준다.
private struct SystemStatusRows: View {
    let load: SystemLoad?

    var body: some View {
        VStack(spacing: 7) {
            row("CPU", value: load?.cpu, effect: load.map { tr("헤엄 ×\(String(format: "%.1f", $0.swimSpeed))", "Swim ×\(String(format: "%.1f", $0.swimSpeed))") })
            row(tr("메모리", "Memory"), value: load?.memory, effect: load.map { $0.turbidity > 0.01 ? tr("물 흐림", "Cloudy") : tr("물 맑음", "Clear") })
            batteryRow
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var batteryRow: some View {
        if let load, load.battery == nil {
            HStack {
                Text(tr("배터리", "Battery")).frame(width: 52, alignment: .leading)
                Text(tr("없음 (물 가득)", "None (full water)")).foregroundStyle(.secondary)
                Spacer()
            }
            .font(.caption)
        } else {
            row(tr("배터리", "Battery"), value: load?.battery,
                effect: load.map { $0.isCharging ? tr("충전 중 · 물 가득", "Charging · full") : tr("물 \(Int($0.waterLevel * 100))%", "Water \(Int($0.waterLevel * 100))%") })
        }
    }

    private func row(_ title: String, value: Double?, effect: String?) -> some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 52, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.accentColor).frame(width: proxy.size.width * CGFloat(value ?? 0))
                }
            }
            .frame(height: 6)
            Text(value.map { "\(Int($0 * 100))%" } ?? "–").monospacedDigit().frame(width: 38, alignment: .trailing)
            Text(effect ?? "").foregroundStyle(.secondary).frame(width: 96, alignment: .leading).lineLimit(1)
        }
        .font(.caption)
    }
}
