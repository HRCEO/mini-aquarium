import MiniAquariumCore
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case timer, tank, fish, decor, info
    var id: Self { self }

    var title: String {
        switch self {
        case .timer: return tr("타이머", "Timer")
        case .tank: return tr("어항", "Tank")
        case .fish: return tr("물고기", "Fish")
        case .decor: return tr("꾸미기", "Decorate")
        case .info: return tr("정보", "Info")
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
        case .both: return tr("둘 다", "Both")
        case .food: return tr("먹이만", "Food only")
        case .time: return tr("시간만", "Time only")
        case .none: return tr("숨김", "Hidden")
        }
    }

    var hint: String {
        switch self {
        case .both: return tr("노란 먹이 띠를 물고기가 갉아먹고, 남은 시간 글씨도 보여요.", "Fish nibble a yellow food bar, and the time left is shown.")
        case .food: return tr("먹이 띠만 줄어들어요. 남은 시간 글씨는 숨겨요.", "Only the food bar shrinks. The time text is hidden.")
        case .time: return tr("먹이 없이 남은 시간 글씨만 보여요. 물고기는 자유롭게 헤엄쳐요.", "Only the time text is shown, with no food. Fish swim freely.")
        case .none: return tr("타이머가 돌아도 어항은 평소 모습 그대로예요.", "The tank looks the same while the timer runs.")
        }
    }
}

private enum DockGapChoice {
    static let values = [0, 8, 14, 24, 40, 60]
    static func title(_ value: Int) -> String {
        switch value {
        case 0: return tr("붙임", "Touching")
        case 8: return tr("좁게", "Narrow")
        case 14: return tr("보통", "Normal")
        case 24: return tr("넓게", "Wide")
        case 40: return tr("더 넓게", "Wider")
        default: return tr("최대", "Max")
        }
    }
}

private enum TimerInput: String, CaseIterable {
    case duration, clock
    var title: String { self == .duration ? tr("지금부터", "From now") : tr("시각 지정", "At a time") }
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
        Section(tr("어항에 보여줄 것", "Show in tank")) {
            Segmented(options: TimerLook.allCases, selected: TimerLook(settings), label: \.title) { look in
                model.update { $0.with(showTimerFood: look.showsFood).with(showRemaining: look.showsTime) }
            }
            Text(TimerLook(settings).hint).font(.caption).foregroundStyle(.secondary)
        }
        if let timer = model.timer {
            VStack(spacing: 8) {
                Text(tr("남은 시간", "Time left")).font(.caption).foregroundStyle(.secondary)
                Text(TimerState.format(timer.remaining(at: Date())))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                Text(tr("\(timer.end.formatted(date: .omitted, time: .shortened))에 끝나요", "Ends at \(timer.end.formatted(date: .omitted, time: .shortened))"))
                    .font(.caption).foregroundStyle(.secondary)
                Button(tr("취소", "Cancel"), role: .destructive, action: model.cancelTimer).padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        } else {
            Segmented(options: TimerInput.allCases, selected: timerInput, label: \.title) { timerInput = $0 }
            if timerInput == .duration { durationInput } else { clockInput }
            Button(action: startTimer) {
                Text(tr("시작", "Start")).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 5)
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
                Nudger(value: "\(settings.timerMinutes / 60)", unit: tr("시간", "hr"),
                       minus: { shiftMinutes(-60) }, plus: { shiftMinutes(60) },
                       commit: { setMinutes(hours: $0, minutes: settings.timerMinutes % 60) })
                Nudger(value: "\(settings.timerMinutes % 60)", unit: tr("분", "min"),
                       minus: { shiftMinutes(-1) }, plus: { shiftMinutes(1) },
                       commit: { setMinutes(hours: settings.timerMinutes / 60, minutes: $0) })
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                ForEach([25, 50, 90, 180, 480], id: \.self) { minutes in
                    Chip(title: Self.shortDuration(minutes), isSelected: settings.timerMinutes == minutes) {
                        model.update { $0.with(timerMinutes: minutes) }
                    }
                }
            }
            Text(tr("\(Self.longDuration(settings.timerMinutes)) 뒤에 알려줘요", "Alerts in \(Self.longDuration(settings.timerMinutes))"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var clockInput: some View {
        let minute = settings.targetMinuteOfDay
        let wait = TimerState.until(minuteOfDay: minute, from: Date()).duration
        return VStack(spacing: 14) {
            HStack(spacing: 18) {
                Nudger(value: String(format: "%02d", minute / 60), unit: tr("시", "hr"),
                       minus: { shiftTarget(-60) }, plus: { shiftTarget(60) },
                       commit: { setTarget(hour: $0, minute: minute % 60) })
                Nudger(value: String(format: "%02d", minute % 60), unit: tr("분", "min"),
                       minus: { shiftTarget(-1) }, plus: { shiftTarget(1) },
                       commit: { setTarget(hour: minute / 60, minute: $0) })
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                ForEach([(12 * 60, tr("점심 12:00", "Lunch 12:00")), (17 * 60 + 30, "17:30"), (18 * 60, tr("퇴근 18:00", "Leave 18:00"))], id: \.0) { item in
                    Chip(title: item.1, isSelected: minute == item.0) {
                        model.update { $0.with(targetMinuteOfDay: item.0) }
                    }
                }
            }
            Text(tr("\(Self.longDuration(Int((wait / 60).rounded(.up)))) 뒤에 알려줘요", "Alerts in \(Self.longDuration(Int((wait / 60).rounded(.up))))"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func shiftMinutes(_ delta: Int) {
        model.update { $0.with(timerMinutes: $0.timerMinutes + delta) }
    }

    /// 키보드 입력: 분 칸에 90을 쳐도 총 시간으로 합산하고, 전체 범위(1분~10시간)로 보정된다.
    private func setMinutes(hours: Int, minutes: Int) {
        model.update { $0.with(timerMinutes: hours * 60 + minutes) }
    }

    /// 키보드 입력: 시는 0~23, 분은 0~59로 보정한다.
    private func setTarget(hour: Int, minute: Int) {
        model.update { $0.with(targetMinuteOfDay: min(max(hour, 0), 23) * 60 + min(max(minute, 0), 59)) }
    }

    private func shiftTarget(_ delta: Int) {
        model.update { $0.with(targetMinuteOfDay: $0.targetMinuteOfDay + delta) }
    }

    private static func shortDuration(_ minutes: Int) -> String {
        minutes % 60 == 0 ? tr("\(minutes / 60)시간", "\(minutes / 60) hr") : tr("\(minutes)분", "\(minutes) min")
    }

    private static func longDuration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return tr("\(m)분", "\(m) min") }
        return m == 0 ? tr("\(h)시간", "\(h) hr") : tr("\(h)시간 \(m)분", "\(h) hr \(m) min")
    }

    // MARK: - Tank

    private var dockIsVertical: Bool { DockPlacement.current()?.isVertical ?? true }

    @ViewBuilder private var tankPage: some View {
        Section(tr("표시", "Display")) {
            Segmented(options: DisplayMode.allCases, selected: settings.displayMode,
                      label: { $0 == .floating ? tr("화면에 띄우기", "On screen") : tr("메뉴바에서만", "Menu bar only") }) { mode in
                model.update { $0.with(displayMode: mode) }
            }
        }
        if settings.displayMode == .floating {
            Section(tr("배치", "Layout")) {
                Segmented(options: [true, false], selected: settings.dockFit, label: { $0 ? tr("Dock에 고정", "Fit to Dock") : tr("플로팅", "Floating") }) { fit in
                    model.update { $0.with(dockFit: fit) }
                }
                Text(settings.dockFit
                     ? tr("Dock 아이콘 줄 \(dockIsVertical ? "위·아래" : "왼쪽·오른쪽")의 빈 자리를 꽉 채워요. Dock에 자리가 없으면 자동으로 플로팅으로 보여줘요.", "Fills the empty space \(dockIsVertical ? "above and below" : "left and right of") the Dock icons. Falls back to floating if there is no room.")
                     : tr("Dock과 상관없이 화면 위에 띄워요. 끌어서 옮길 수 있어요.", "Floats on screen regardless of the Dock. Drag to move it."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if settings.displayMode == .floating, settings.dockFit {
            Section(tr("어항 위치", "Tank position")) {
                Segmented(options: DockEdge.allCases, selected: settings.dockEdge, label: { $0.title(vertical: dockIsVertical) }) { edge in
                    model.update { $0.with(dockEdge: edge) }
                }
                Text(tr("양쪽을 고르면 Dock 양옆이 하나로 이어진 긴 어항이 돼요.", "Choose both sides to join the two sides of the Dock into one long tank."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if settings.displayMode == .floating, settings.dockFit {
            Section(tr("Dock과의 간격", "Gap from Dock")) {
                Segmented(options: DockGapChoice.values, selected: settings.dockGap, label: DockGapChoice.title) { gap in
                    model.update { $0.with(dockGap: gap) }
                }
            }
        }
        if settings.displayMode == .floating, settings.dockFit {
            AccessibilityCard()
        }
        Section(tr("물고기·소품 크기", "Fish & decor size")) {
            Segmented(options: ObjectSize.allCases, selected: settings.objectSize, label: \.title) { objectSize in
                model.update { $0.with(objectSize: objectSize) }
            }
        }
        if settings.displayMode == .menuBar || !settings.dockFit || !model.isDocked {
            Section(tr("크기", "Size")) {
                Segmented(options: TankSize.allCases, selected: settings.size, label: \.title) { size in
                    model.update { $0.with(size: size) }
                }
            }
            Section(tr("비율", "Shape")) {
                Segmented(options: TankLayout.allCases, selected: settings.layout, label: \.shortTitle) { layout in
                    model.update { $0.with(layout: layout) }
                }
            }
            Section(tr("모양", "Style")) {
                Segmented(options: TankShape.allCases, selected: settings.shape,
                          label: { $0.title.replacingOccurrences(of: tr(" 어항", " tank"), with: "") }) { shape in
                    model.update { $0.with(shape: shape) }
                }
            }
        }
        SystemLinkControls(model: model)
    }

    // MARK: - Fish / decor

    @ViewBuilder private var fishPage: some View {
        HStack {
            Text(tr("\(settings.fish.count) / \(AquariumSettings.maxFish)마리", "\(settings.fish.count) / \(AquariumSettings.maxFish) fish"))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
                model.update { $0.resettingFish() }
            } label: {
                Label(tr("추천 설정", "Recommended"), systemImage: "wand.and.stars")
            }
            .controlSize(.small)
            .disabled(settings.fish == AquariumSettings.recommendedFish)
            .help(tr("물고기 수와 종류를 추천 구성(10마리)으로 맞춰요", "Reset fish to the recommended set (10 fish)"))
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
            // 바닥 생물도 물고기와 같은 식구다. 소품이 아니라 이 목록에 둔다.
            ForEach(CritterKind.allCases, id: \.self) { kind in
                CritterCard(
                    kind: kind,
                    count: settings.count(ofCritter: kind),
                    canAdd: settings.critters.count < AquariumSettings.maxCritters,
                    add: { model.update { $0.addingCritter(kind) } },
                    remove: { model.update { $0.removingCritter(kind) } }
                )
            }
        }
    }

    @ViewBuilder private var infoPage: some View {
        Section("언어 / Language") {
            Segmented(options: Language.allCases, selected: settings.language, label: { $0.nativeName }) { language in
                model.update { $0.with(language: language) }
            }
        }
        Section(tr("시작", "Start")) {
            Toggle(isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) })) {
                Text(tr("로그인할 때 자동 실행", "Launch at login")).font(.system(size: 12.5))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            if let launchError {
                Text(launchError).font(.caption).foregroundStyle(.red)
            } else if !LaunchAtLogin.isAvailable {
                Text(tr("앱(.app)으로 실행했을 때만 설정할 수 있어요.", "Only available when run as an app (.app).")).font(.caption).foregroundStyle(.secondary)
            }
        }
        Section(tr("권한", "Permissions")) {
            AccessibilityCard(alwaysShow: true)
        }
        Section(tr("앱 정보", "About")) {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: tr("버전", "Version"), value: AppInfo.version)
                InfoRow(label: tr("제작자", "Author"), value: AppInfo.author)
                InfoRow(label: tr("이메일", "Email"), value: AppInfo.email)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        if let supportURL = AppInfo.supportURL {
            Section(tr("후원", "Support")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("미니 어항이 마음에 드셨다면 커피 한 잔으로 응원해 주세요.", "If you enjoy Mini Aquarium, you can buy me a coffee."))
                        .font(.caption).foregroundStyle(.secondary)
                    Link(destination: supportURL) {
                        Label(tr("Ko-fi에서 후원하기", "Support on Ko-fi"), systemImage: "cup.and.saucer.fill")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            try LaunchAtLogin.set(on)
            launchError = nil
        } catch {
            launchError = tr("설정하지 못했어요: \(error.localizedDescription)", "Could not change: \(error.localizedDescription)")
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    @ViewBuilder private var statusFishSection: some View {
        Section(tr("메뉴바 아이콘", "Menu bar icon")) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(Species.allCases, id: \.self) { species in
                    StatusFishChip(species: species, isSelected: settings.statusFish == species) {
                        model.update { $0.with(statusFish: species) }
                    }
                }
            }
            Text(tr("화면 위쪽 메뉴바에서 헤엄치는 물고기를 골라요.", "Pick the fish that swims in the menu bar."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var decorPage: some View {
        Section(tr("먹이", "Food")) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(FoodKind.allCases, id: \.self) { kind in
                    FoodCard(kind: kind, isSelected: settings.food == kind) { model.update { $0.with(food: kind) } }
                }
            }
        }
        Section(tr("소품", "Decor")) {
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

struct Section<Content: View>: View {
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
                Text(granted ? tr("손쉬운 사용 권한 허용됨", "Accessibility access granted") : tr("손쉬운 사용 권한이 필요해요", "Accessibility access needed"))
                    .font(.system(size: 12.5, weight: .semibold))
            }
            Text(granted
                 ? tr("Dock 아이콘 줄의 실제 길이에 맞춰 어항이 자리 잡아요.", "The tank fits the real length of the Dock icons.")
                 : tr("허용하지 않으면 Dock 길이를 어림해서 어항 크기가 조금 어긋날 수 있어요. 열린 목록에서 '미니 어항'을 켜 주세요.", "Without it the Dock length is estimated, so the tank may be slightly off. Turn on 'Mini Aquarium' in the list that opens."))
                .font(.caption).foregroundStyle(.secondary)
            if !granted {
                Button(tr("손쉬운 사용 설정 열기", "Open Accessibility settings")) { DockPlacement.openAccessibilitySettings() }
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

struct ToggleRow: View {
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
/// 눌러서 바로 숫자를 칠 수 있는 큰 숫자 칸. Return이나 포커스를 잃을 때 반영하고, 숫자가 아니면 원래 값으로 되돌린다.
private struct NumberField: View {
    let value: String
    let commit: (Int) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(width: 52)
            .focused($isFocused)
            .onAppear { text = value }
            .onChange(of: value) { new in if !isFocused { text = new } }
            .onChange(of: text) { new in
                let digits = String(new.filter(\.isNumber).prefix(3))
                if digits != new { text = digits }
            }
            .onChange(of: isFocused) { focused in
                if focused { text = "" } else { apply() }
            }
            .onSubmit { isFocused = false }
    }

    private func apply() {
        if let number = Int(text) { commit(number) }
        text = value
        // 반영 결과(범위 보정 등)가 value에 늦게 도착할 수 있어 한 번 더 맞춘다.
        DispatchQueue.main.async { if !isFocused { text = value } }
    }
}

struct Nudger: View {
    let value: String
    let unit: String
    let minus: () -> Void
    let plus: () -> Void
    /// 키보드로 직접 입력한 숫자를 받는다.
    let commit: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            round("minus", minus)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                NumberField(value: value, commit: commit)
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
                StepButton(symbol: "minus", isEnabled: count > 0, action: remove)
                StepButton(symbol: "plus", isEnabled: canAdd, action: add)
            }
        }
    }
}

/// 마릿수 조절용 작은 +/- 버튼.
private struct StepButton: View {
    let symbol: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

/// 바닥 생물 미리보기 카드: 모래 위를 걷는 모습과 이름, 마릿수 조절.
private struct CritterCard: View {
    let kind: CritterKind
    let count: Int
    let canAdd: Bool
    let add: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    context.fill(Path(CGRect(x: 0, y: size.height - 12, width: size.width, height: 12)),
                                 with: Art.vertical(Art.c(0.95, 0.87, 0.66), Art.c(0.78, 0.66, 0.46), size.height - 12, size.height))
                    context.translateBy(x: size.width / 2, y: size.height - 8)
                    context.scaleBy(x: 1.6, y: 1.6)
                    CritterArt.draw(kind, in: &context, gait: t, isMoving: true, facingRight: true, t: t, phase: 0)
                }
            }
            .frame(height: 62)
            .background(previewWater, in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule()).padding(4)
                }
            }
            Text(kind.title).font(.system(size: 11.5, weight: .medium))
            HStack(spacing: 4) {
                StepButton(symbol: "minus", isEnabled: count > 0, action: remove)
                StepButton(symbol: "plus", isEnabled: canAdd, action: add)
            }
        }
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
