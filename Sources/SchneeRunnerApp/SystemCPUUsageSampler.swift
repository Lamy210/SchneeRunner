import Darwin
import Foundation
import SchneeRunnerCore

enum SystemCPUUsageSamplerError: Error, LocalizedError {
    case hostStatisticsFailed(kernReturn: kern_return_t)

    var errorDescription: String? {
        switch self {
        case let .hostStatisticsFailed(kernReturn):
            "Could not read system CPU statistics (Mach error \(kernReturn))."
        }
    }
}

struct SystemCPUUsageSampler {
    func readSnapshot() throws -> CPUTickSnapshot {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size
                / MemoryLayout<integer_t>.size
        )

        let hostPort = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, hostPort)
        }

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { reboundPointer in
                host_statistics(
                    hostPort,
                    HOST_CPU_LOAD_INFO,
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw SystemCPUUsageSamplerError.hostStatisticsFailed(kernReturn: result)
        }

        return CPUTickSnapshot(
            user: UInt64(loadInfo.cpu_ticks.0),
            system: UInt64(loadInfo.cpu_ticks.1),
            idle: UInt64(loadInfo.cpu_ticks.2),
            nice: UInt64(loadInfo.cpu_ticks.3)
        )
    }
}
