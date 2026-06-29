import Foundation

func runBlocking<T>(_ block: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = BlockingResultBox<T>()

    Task.detached(priority: .userInitiated) {
        do {
            box.result = .success(try await block())
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    return try box.result.get()
}

private final class BlockingResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>!
}
