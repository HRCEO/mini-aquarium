import Darwin
import Foundation
import IOKit.ps
import MiniAquariumCore

/// macOS에서 CPU·메모리·배터리 상태를 읽어 `SystemLoad`로 돌려준다.
///
/// CPU는 이전 호출과의 틱 차이로 구하므로, 같은 인스턴스를 계속 쓰고 호출 간격이 어느 정도 있어야 의미가 있다.
/// 읽기에 실패한 항목은 "한가함/배터리 없음"으로 취급해 어항이 평소 모습을 유지하게 한다.
final class SystemMonitor {
    private var lastCPU: (busy: UInt64, total: UInt64)?

    func sample() -> SystemLoad {
        let battery = Self.readBattery()
        return SystemLoad(
            cpu: readCPU(),
            memory: Self.readMemory(),
            battery: battery?.level,
            isCharging: battery?.isPluggedIn ?? false
        )
    }

    // MARK: - CPU

    private func readCPU() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let ticks = info.cpu_ticks
        let busy = UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3)   // user + system + nice
        let total = busy + UInt64(ticks.2)                               // + idle
        defer { lastCPU = (busy, total) }
        guard let last = lastCPU, total > last.total, busy >= last.busy else { return 0 }
        return Double(busy - last.busy) / Double(total - last.total)
    }

    // MARK: - Memory

    /// 쓰는 중인 메모리 비율. 활성 + 고정(wired) + 압축된 페이지를 쓴 것으로 본다.
    private static func readMemory() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS, total > 0 else { return 0 }
        let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return Double(pages) * Double(sysconf(_SC_PAGESIZE)) / total
    }

    // MARK: - Battery

    /// 내장 배터리의 잔량(0...1)과 전원 연결 여부. 배터리가 없는 Mac이면 nil.
    private static func readBattery() -> (level: Double, isPluggedIn: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let capacity = description[kIOPSMaxCapacityKey] as? Int,
                  capacity > 0
            else { continue }
            let isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return (Double(current) / Double(capacity), isPluggedIn)
        }
        return nil
    }
}
