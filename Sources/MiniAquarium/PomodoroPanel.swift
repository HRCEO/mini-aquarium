import MiniAquariumCore
import SwiftUI

/// 타이머 탭 아래의 포모도로 영역. 기능을 끄면 스위치 한 줄만 남는다.
struct PomodoroControls: View {
    @ObservedObject var model: AquariumModel

    private var settings: AquariumSettings { model.settings }
    private var plan: PomodoroPlan { settings.pomodoro }

    var body: some View {
        Divider()
        Section(tr("포모도로", "Pomodoro")) {
            ToggleRow(title: tr("포모도로 사용", "Use Pomodoro"), isOn: settings.pomodoroEnabled) { isOn in
                model.update { $0.with(pomodoroEnabled: isOn) }
            }
            if settings.pomodoroEnabled { content }
        }
    }

    @ViewBuilder private var content: some View {
        if let session = model.pomodoro {
            running(session)
        } else if model.timer == nil {
            setup
        } else {
            Text(tr("일반 타이머가 끝나면 포모도로를 시작할 수 있어요.", "You can start a Pomodoro once the current timer ends."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func running(_ session: PomodoroSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(phaseTitle(session))
                .font(.system(size: 13, weight: .semibold))
            Text(tr("오늘 끝낸 집중 \(session.completedFocus)번", "\(session.completedFocus) focus sessions done"))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(tr("다음 단계로", "Skip"), action: model.skipPomodoroPhase)
                Button(tr("그만하기", "Stop"), role: .destructive, action: model.cancelTimer)
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                nudger(tr("집중", "Focus"), minutes: plan.focusMinutes, step: 5) { plan.with(focus: $0) }
                nudger(tr("휴식", "Break"), minutes: plan.shortBreakMinutes, step: 1) { plan.with(shortBreak: $0) }
                nudger(tr("긴 휴식", "Long break"), minutes: plan.longBreakMinutes, step: 5) { plan.with(longBreak: $0) }
                cycleNudger
            }
            Button(action: model.startPomodoro) {
                Text(tr("포모도로 시작", "Start Pomodoro")).font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            Text(tr("집중 → 휴식이 자동으로 이어져요. 단계가 바뀔 때 소리와 어항이 알려줘요.", "Focus and breaks follow automatically. The tank and a sound tell you when it changes."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func nudger(_ title: String, minutes: Int, step: Int, change: @escaping (Int) -> PomodoroPlan) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Nudger(value: "\(minutes)", unit: tr("분", "min"),
                   minus: { apply(change(minutes - step)) }, plus: { apply(change(minutes + step)) },
                   commit: { apply(change($0)) })
        }
    }

    private var cycleNudger: some View {
        VStack(spacing: 2) {
            Text(tr("긴 휴식 주기", "Long break every")).font(.caption).foregroundStyle(.secondary)
            Nudger(value: "\(plan.cyclesBeforeLongBreak)", unit: tr("회", "x"),
                   minus: { apply(plan.with(cycles: plan.cyclesBeforeLongBreak - 1)) },
                   plus: { apply(plan.with(cycles: plan.cyclesBeforeLongBreak + 1)) },
                   commit: { apply(plan.with(cycles: $0)) })
        }
    }

    private func apply(_ next: PomodoroPlan) { model.update { $0.with(pomodoro: next) } }

    private func phaseTitle(_ session: PomodoroSession) -> String {
        switch session.phase {
        case .focus: return tr("🍅 집중 \(session.focusIndexInSet(plan: plan))/\(plan.cyclesBeforeLongBreak)", "🍅 Focus \(session.focusIndexInSet(plan: plan))/\(plan.cyclesBeforeLongBreak)")
        case .shortBreak: return tr("☕ 휴식 중", "☕ On a break")
        case .longBreak: return tr("🌴 긴 휴식 중", "🌴 On a long break")
        }
    }
}

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
