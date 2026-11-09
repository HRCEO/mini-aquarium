import MiniAquariumCore
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case timer, tank, fish, decor, info
    var id: Self { self }

    var title: String {
        switch self {
        case .timer: return "타이머"
        case .tank: return "어항"
        case .fish: return "물고기"
        case .decor: return "꾸미기"
        case .info: return "정보"
        }
    }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .tank: return "square.dashed"
        case .fish: return "fish"
        case .decor: return "leaf"
        case .info: return "info.circle"
        }
    }
}

/// 타이머가 도는 동안 어항에 무엇을 보여줄지.
private enum TimerLook: CaseIterable {
    case both, food, time, none

    init(_ settings: AquariumSettings) {
        switch (settings.showTimerFood, settings.showRemaining) {
        case (true, true): self = .both
        case (true, false): self = .food
        case (false, true): self = .time
        case (false, false): self = .none
        }
    }

    var showsFood: Bool { self == .both || self == .food }
    var showsTime: Bool { self == .both || self == .time }

    var title: String {
        switch self {
        case .both: return "둘 다"
        case .food: return "먹이만"
        case .time: return "시간만"
        case .none: return "숨김"
        }
    }

    var hint: String {
        switch self {
        case .both: return "노란 먹이 띠를 물고기가 갉아먹고, 남은 시간 글씨도 보여요."
        case .food: return "먹이 띠만 줄어들어요. 남은 시간 글씨는 숨겨요."
        case .time: return "먹이 없이 남은 시간 글씨만 보여요. 물고기는 자유롭게 헤엄쳐요."
        case .none: return "타이머가 돌아도 어항은 평소 모습 그대로예요."
        }
    }
}

private enum DockGapChoice {
    static let values = [0, 8, 14, 24, 40, 60]
    static func title(_ value: Int) -> String {
        switch value {
        case 0: return "붙임"
        case 8: return "좁게"
        case 14: return "보통"
        case 24: return "넓게"
        case 40: return "더 넓게"
        default: return "최대"
        }
    }
}

private enum TimerInput: String, CaseIterable {
    case duration, clock
    var title: String { self == .duration ? "지금부터" : "시각 지정" }
}

/// 팝오버 안의 설정 화면. 탭으로 나눠 한 번에 하나만 보여 준다.
struct SettingsPanel: View {
    @ObservedObject var model: AquariumModel
    @State private var tab: SettingsTab = .timer
    @State private var timerInput: TimerInput = .duration
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    private var settings: AquariumSettings { model.settings }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .timer: timerPage
                    case .tank: tankPage
                    case .fish: fishPage
                    case .decor: decorPage
                    case .info: infoPage
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 340)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { item in
                Button { tab = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 14, weight: .medium))
                        Text(item.title).font(.system(size: 10.5, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(tab == item ? Color.accentColor : .secondary)
                    .overlay(alignment: .bottom) {
                        Capsule().fill(Color.accentColor).frame(width: 22, height: 2.5)
                            .opacity(tab == item ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.horizontal, 6)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Timer

    @ViewBuilder private var timerPage: some View {
        Section("어항에 보여줄 것") {
            Segmented(options: TimerLook.allCases, selected: TimerLook(settings), label: \.title) { look in
                model.update { $0.with(showTimerFood: look.showsFood).with(showRemaining: look.showsTime) }
            }
            Text(TimerLook(settings).hint).font(.caption).foregroundStyle(.secondary)
        }
        if let timer = model.timer {
            VStack(spacing: 8) {
                Text("남은 시간").font(.caption).foregroundStyle(.secondary)
                Text(TimerState.format(timer.remaining(at: Date())))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                Text("\(timer.end.formatted(date: .omitted, time: .shortened))에 끝나요")
                    .font(.caption).foregroundStyle(.secondary)
                Button("취소", role: .destructive, action: model.cancelTimer).padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        } else {
            Segmented(options: TimerInput.allCases, selected: timerInput, label: \.title) { timerInput = $0 }
            if timerInput == .duration { durationInput } else { clockInput }
            Button(action: startTimer) {
                Text("시작").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func startTimer() {
        if timerInput == .duration {
            model.startTimer(minutes: Double(settings.timerMinutes))
        } else {
            model.startTimer(untilMinuteOfDay: settings.targetMinuteOfDay)
        }
    }

    private var durationInput: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                Nudger(value: "\(settings.timerMinutes / 60)", unit: "시간",
                       minus: { shiftMinutes(-60) }, plus: { shiftMinutes(60) })
                Nudger(value: "\(settings.timerMinutes % 60)", unit: "분",
                       minus: { shiftMinutes(-5) }, plus: { shiftMinutes(5) })
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                ForEach([25, 50, 90, 180, 480], id: \.self) { minutes in
                    Chip(title: Self.shortDuration(minutes), isSelected: settings.timerMinutes == minutes) {
                        model.update { $0.with(timerMinutes: minutes) }
                    }
                }
            }
            Text("\(Self.longDuration(settings.timerMinutes)) 뒤에 알려줘요")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var clockInput: some View {
        let minute = settings.targetMinuteOfDay
        let wait = TimerState.until(minuteOfDay: minute, from: Date()).duration
        return VStack(spacing: 14) {
            HStack(spacing: 18) {
                Nudger(value: String(format: "%02d", minute / 60), unit: "시",
                       minus: { shiftTarget(-60) }, plus: { shiftTarget(60) })
                Nudger(value: String(format: "%02d", minute % 60), unit: "분",
                       minus: { shiftTarget(-5) }, plus: { shiftTarget(5) })
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                ForEach([(12 * 60, "점심 12:00"), (17 * 60 + 30, "17:30"), (18 * 60, "퇴근 18:00")], id: \.0) { item in
                    Chip(title: item.1, isSelected: minute == item.0) {
                        model.update { $0.with(targetMinuteOfDay: item.0) }
                    }
                }
            }
            Text("\(Self.longDuration(Int((wait / 60).rounded(.up)))) 뒤에 알려줘요")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func shiftMinutes(_ delta: Int) {
        model.update { $0.with(timerMinutes: $0.timerMinutes + delta) }
    }

    private func shiftTarget(_ delta: Int) {
        model.update { $0.with(targetMinuteOfDay: $0.targetMinuteOfDay + delta) }
    }

    private static func shortDuration(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60)시간" : "\(minutes)분"
    }

    private static func longDuration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)분" }
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }

    // MARK: - Tank

    private var dockIsVertical: Bool { DockPlacement.current()?.isVertical ?? true }

    @ViewBuilder private var tankPage: some View {
        Section("표시") {
            Segmented(options: DisplayMode.allCases, selected: settings.displayMode,
                      label: { $0 == .floating ? "화면에 띄우기" : "메뉴바에서만" }) { mode in
                model.update { $0.with(displayMode: mode) }
            }
        }
        if settings.displayMode == .floating {
            Section("배치") {
                Segmented(options: [true, false], selected: settings.dockFit, label: { $0 ? "Dock에 고정" : "플로팅" }) { fit in
                    model.update { $0.with(dockFit: fit) }
                }
                Text(settings.dockFit
                     ? "Dock 아이콘 줄 \(dockIsVertical ? "위·아래" : "왼쪽·오른쪽")의 빈 자리를 꽉 채워요. Dock에 자리가 없으면 자동으로 플로팅으로 보여줘요."
                     : "Dock과 상관없이 화면 위에 띄워요. 끌어서 옮길 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if settings.displayMode == .floating, settings.dockFit {
            Section("어항 위치") {
                Segmented(options: DockEdge.allCases, selected: settings.dockEdge, label: { $0.title(vertical: dockIsVertical) }) { edge in
                    model.update { $0.with(dockEdge: edge) }
                }
                Text("양쪽을 고르면 Dock 양옆이 하나로 이어진 긴 어항이 돼요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if settings.displayMode == .floating, settings.dockFit {
            Section("Dock과의 간격") {
                Segmented(options: DockGapChoice.values, selected: settings.dockGap, label: DockGapChoice.title) { gap in
                    model.update { $0.with(dockGap: gap) }
                }
            }
        }
        if settings.displayMode == .floating, settings.dockFit {
            AccessibilityCard()
        }
        Section("물고기·소품 크기") {
            Segmented(options: ObjectSize.allCases, selected: settings.objectSize, label: \.title) { objectSize in
                model.update { $0.with(objectSize: objectSize) }
            }
        }
        if settings.displayMode == .menuBar || !settings.dockFit || !model.isDocked {
            Section("크기") {
                Segmented(options: TankSize.allCases, selected: settings.size, label: \.title) { size in
                    model.update { $0.with(size: size) }
                }
            }
            Section("비율") {
                Segmented(options: TankLayout.allCases, selected: settings.layout, label: \.shortTitle) { layout in
                    model.update { $0.with(layout: layout) }
                }
            }
            Section("모양") {
                Segmented(options: TankShape.allCases, selected: settings.shape,
                          label: { $0.title.replacingOccurrences(of: " 어항", with: "") }) { shape in
                    model.update { $0.with(shape: shape) }
                }
            }
        }
    }

    // MARK: - Fish / decor

    @ViewBuilder private var fishPage: some View {
        HStack {
            Text("\(settings.fish.count) / \(AquariumSettings.maxFish)마리")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
                model.update { $0.resettingFish() }
            } label: {
                Label("추천 설정", systemImage: "wand.and.stars")
            }
            .controlSize(.small)
            .disabled(settings.fish == AquariumSettings.recommendedFish)
            .help("물고기 수와 종류를 추천 구성(10마리)으로 맞춰요")
        }
        statusFishSection
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
            ForEach(Species.allCases, id: \.self) { species in
                FishCard(
                    species: species,
                    count: settings.count(of: species),
                    canAdd: settings.fish.count < AquariumSettings.maxFish,
                    add: { model.update { $0.adding(species) } },
                    remove: { model.update { $0.removing(species) } }
                )
            }
        }
    }

    @ViewBuilder private var infoPage: some View {
        Section("시작") {
            Toggle(isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) })) {
                Text("로그인할 때 자동 실행").font(.system(size: 12.5))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            if let launchError {
                Text(launchError).font(.caption).foregroundStyle(.red)
            } else if !LaunchAtLogin.isAvailable {
                Text("앱(.app)으로 실행했을 때만 설정할 수 있어요.").font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("권한") {
            AccessibilityCard(alwaysShow: true)
        }
        Section("앱 정보") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "버전", value: AppInfo.version)
                InfoRow(label: "제작자", value: AppInfo.author)
                InfoRow(label: "이메일", value: AppInfo.email)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            try LaunchAtLogin.set(on)
            launchError = nil
        } catch {
            launchError = "설정하지 못했어요: \(error.localizedDescription)"
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    @ViewBuilder private var statusFishSection: some View {
        Section("메뉴바 아이콘") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(Species.allCases, id: \.self) { species in
                    StatusFishChip(species: species, isSelected: settings.statusFish == species) {
                        model.update { $0.with(statusFish: species) }
                    }
                }
            }
            Text("화면 위쪽 메뉴바에서 헤엄치는 물고기를 골라요.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var decorPage: some View {
        Section("먹이") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(FoodKind.allCases, id: \.self) { kind in
                    FoodCard(kind: kind, isSelected: settings.food == kind) { model.update { $0.with(food: kind) } }
                }
            }
        }
        Section("소품") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(Decor.allCases, id: \.self) { decor in
                    DecorCard(decor: decor, isOn: settings.decors.contains(decor)) {
                        model.update { $0.toggling(decor) }
                    }
                }
            }
        }
    }
}

// MARK: - Building blocks

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content
        }
    }
}

private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

/// 트랙 안에서 선택된 칸이 채워지는 세그먼트 컨트롤.
private struct Segmented<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let label: (Option) -> String
    let onChange: (Option) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button { onChange(option) } label: {
                    Text(label(option))
                        .font(.system(size: 12, weight: option == selected ? .semibold : .regular))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(option == selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(option == selected ? Color.white : .primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// 손쉬운 사용 권한 상태와 설정 열기 버튼. 권한이 있으면 Dock 길이를 정확히 읽는다.
private struct AccessibilityCard: View {
    var alwaysShow = false
    @State private var granted = DockPlacement.isAccessibilityGranted

    var body: some View {
        Group {
            if !granted || alwaysShow { card }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let now = DockPlacement.isAccessibilityGranted
            if now != granted { granted = now }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? Color.green : Color.orange)
                Text(granted ? "손쉬운 사용 권한 허용됨" : "손쉬운 사용 권한이 필요해요")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            Text(granted
                 ? "Dock 아이콘 줄의 실제 길이에 맞춰 어항이 자리 잡아요."
                 : "허용하지 않으면 Dock 길이를 어림해서 어항 크기가 조금 어긋날 수 있어요. 열린 목록에서 '미니 어항'을 켜 주세요.")
                .font(.caption).foregroundStyle(.secondary)
            if !granted {
                Button("손쉬운 사용 설정 열기") { DockPlacement.openAccessibilitySettings() }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            Text(value).font(.system(size: 12.5, weight: .medium)).textSelection(.enabled)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let isOn: Bool
    let change: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: change)) {
            Text(title).font(.system(size: 12.5))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}

/// 큰 숫자 + 위아래 조절 버튼.
private struct Nudger: View {
    let value: String
    let unit: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            round("minus", minus)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                Text(unit).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(minWidth: 62)
            round("plus", plus)
        }
    }

    private func round(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.16), in: Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

// MARK: - Preview cards

private let previewWater = LinearGradient(colors: [Art.c(0.42, 0.76, 0.92), Art.c(0.12, 0.42, 0.7)], startPoint: .top, endPoint: .bottom)

/// 물고기 미리보기 카드: 움직이는 모습과 이름, 마릿수 조절.
private struct StatusFishChip: View {
    let species: Species
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Canvas { context, size in
                let side = min(size.width, size.height) * (species.isUpright ? 0.8 : 0.95)
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.scaleBy(x: side, y: side)
                FishArt.draw(species, in: &context, t: 0.6, eating: 0)
            }
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(isSelected ? 0.2 : 0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(species.title)
    }
}

private struct FishCard: View {
    let species: Species
    let count: Int
    let canAdd: Bool
    let add: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let side = min(size.width * 0.62, 46) * (species.isUpright ? 1.15 : 1.35)
                    context.translateBy(x: size.width / 2 + CGFloat(sin(t * 1.2)) * 3, y: size.height / 2)
                    context.scaleBy(x: side, y: side)
                    FishArt.draw(species, in: &context, t: t + Double(species.hashValue % 7), eating: 0)
                }
            }
            .frame(height: 62)
            .background(previewWater, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule()).padding(4)
                }
            }
            Text(species.title).font(.system(size: 11.5, weight: .medium))
            HStack(spacing: 4) {
                stepButton("minus", enabled: count > 0, remove)
                stepButton("plus", enabled: canAdd, add)
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

/// 먹이 미리보기 카드: 알갱이를 크게 보여 주고 눌러서 고른다.
private struct FoodCard: View {
    let kind: FoodKind
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 5) {
                Canvas { context, size in
                    let food = Food(kind: kind, pos: .zero, seed: 0.3)   // age 0: 회전 없이 가만히
                    let zoom = 15 / Double(kind.radius)
                    context.translateBy(x: size.width / 2, y: size.height / 2)
                    context.scaleBy(x: zoom, y: zoom)
                    FoodArt.draw(food, in: &context)
                }
                .frame(height: 50)
                .background(previewWater, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2.5))
                Text(kind.title).font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

/// 소품 미리보기 카드: 눌러서 넣고 뺀다.
private struct DecorCard: View {
    let decor: Decor
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 5) {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let scale = min(0.95, 46 / Double(decor.height))
                        context.translateBy(x: size.width / 2, y: size.height - 6)
                        context.scaleBy(x: scale, y: scale)
                        DecorArt.draw(decor, in: &context, t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
                .frame(height: 62)
                .background(previewWater, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isOn ? Color.accentColor : .clear, lineWidth: 2.5))
                .opacity(isOn ? 1 : 0.5)
                HStack(spacing: 3) {
                    if isOn { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                    Text(decor.title).font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

/// 팝오버 전체: (메뉴바 모드면) 어항 + 설정. 세로로 긴 어항은 옆에 나란히 둔다.
struct PopoverContent: View {
    @ObservedObject var model: AquariumModel

    private var tankCap: CGFloat {
        let size = model.logicalSize
        return min(1.4, 380 / size.height, 460 / size.width)
    }

    var body: some View {
        let showTank = model.settings.displayMode == .menuBar
        let settingsHeight: CGFloat = showTank ? 330 : 440
        Group {
            if showTank && model.settings.layout == .slim {
                HStack(spacing: 0) {
                    TankView(model: model, maxScale: tankCap).padding(10)
                    Divider()
                    SettingsPanel(model: model).frame(height: 440)
                }
            } else {
                VStack(spacing: 0) {
                    if showTank {
                        TankView(model: model, maxScale: tankCap).padding(10)
                        Divider()
                    }
                    SettingsPanel(model: model).frame(height: settingsHeight)
                }
                .frame(minWidth: 340)
            }
        }
    }
}
