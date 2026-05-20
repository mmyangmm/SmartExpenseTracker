import Foundation
import CloudKit

actor CloudKitService {
    private static let containerIdentifier = "iCloud.com.Felix.SmartExpenseTracker"

    private lazy var container: CKContainer? = {
        #if targetEnvironment(simulator)
        return nil
        #else
        return CKContainer(identifier: CloudKitService.containerIdentifier)
        #endif
    }()

    private var db: CKDatabase? { container?.privateCloudDatabase }

    // 沒有 iCloud 帳號、Capability 或 container 尚未建立時靜默停用，不會 crash。
    private func isCloudKitAvailable() async -> Bool {
        guard let container else { return false }
        do {
            return try await container.accountStatus() == .available
        } catch {
            print("[CloudKit] unavailable — sync disabled: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Fetch

    func fetchAll() async throws -> [Expense] {
        guard await isCloudKitAvailable(), let db else { return [] }

        let query = CKQuery(recordType: Expense.ckRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        var expenses: [Expense] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (results, nextCursor) = try await fetchPage(db: db, query: query, cursor: cursor)
            expenses.append(contentsOf: results)
            cursor = nextCursor
        } while cursor != nil

        return expenses
    }

    private func fetchPage(
        db: CKDatabase,
        query: CKQuery,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> ([Expense], CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let op: CKQueryOperation
            if let cursor {
                op = CKQueryOperation(cursor: cursor)
            } else {
                op = CKQueryOperation(query: query)
            }
            op.resultsLimit = 200

            var results: [Expense] = []

            op.recordMatchedBlock = { _, result in
                if case .success(let record) = result,
                   let expense = Expense.fromCKRecord(record) {
                    results.append(expense)
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (results, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            db.add(op)
        }
    }

    // MARK: - Save

    func save(_ expense: Expense) async {
        guard await isCloudKitAvailable(), let db else { return }
        let record = expense.toCKRecord()
        do {
            try await db.save(record)
        } catch {
            print("[CloudKit] save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func delete(_ expense: Expense) async {
        guard await isCloudKitAvailable(), let db else { return }
        let recordID = CKRecord.ID(recordName: expense.id)
        do {
            try await db.deleteRecord(withID: recordID)
        } catch {
            print("[CloudKit] delete error: \(error.localizedDescription)")
        }
    }
}
