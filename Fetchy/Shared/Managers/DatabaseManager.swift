import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    // TODO: Use App Group container in production
    let appGroupIdentifier = "group.com.nisesimadao.Fetchy"
    
    // For now, using standard document directory for initial implementation
    private var dbPath: String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("fetchy.sqlite").path
    }
    
    init() {
        openDatabase()
        createTable()
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func createTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS VideoEntries(
            id TEXT PRIMARY KEY,
            title TEXT,
            url TEXT,
            service TEXT,
            date REAL,
            status TEXT,
            localPath TEXT,
            rawLog TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_date ON VideoEntries(date);
        CREATE INDEX IF NOT EXISTS idx_service ON VideoEntries(service);
        CREATE INDEX IF NOT EXISTS idx_status ON VideoEntries(status);
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("VideoEntries table created.")
            } else {
                print("VideoEntries table could not be created.")
            }
        } else {
            print("CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func insert(entry: VideoEntry, rawLog: String? = nil) {
        let insertStatementString = "INSERT INTO VideoEntries (id, title, url, service, date, status, localPath, rawLog) VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            let idStr = entry.id.uuidString as NSString
            let titleStr = entry.title as NSString
            let urlStr = entry.url as NSString
            let serviceStr = entry.service as NSString
            let dateVal = entry.date.timeIntervalSince1970
            let statusStr = entry.status.rawValue as NSString
            let localPathStr = (entry.localPath ?? "") as NSString
            let rawLogStr = (rawLog ?? "") as NSString
            
            sqlite3_bind_text(insertStatement, 1, idStr.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, titleStr.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, urlStr.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, serviceStr.utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 5, dateVal)
            sqlite3_bind_text(insertStatement, 6, statusStr.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 7, localPathStr.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 8, rawLogStr.utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Successfully inserted row.")
            } else {
                print("Could not insert row.")
            }
        } else {
            print("INSERT statement could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
    }
    
    func fetchEntries(limit: Int = 20, offset: Int = 0) -> [VideoEntry] {
        let queryStatementString = "SELECT * FROM VideoEntries ORDER BY date DESC LIMIT ? OFFSET ?;"
        var queryStatement: OpaquePointer?
        var entries: [VideoEntry] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(queryStatement, 1, Int32(limit))
            sqlite3_bind_int(queryStatement, 2, Int32(offset))
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let idStr = String(cString: sqlite3_column_text(queryStatement, 0))
                let title = String(cString: sqlite3_column_text(queryStatement, 1))
                let url = String(cString: sqlite3_column_text(queryStatement, 2))
                let service = String(cString: sqlite3_column_text(queryStatement, 3))
                let dateVal = sqlite3_column_double(queryStatement, 4)
                let statusStr = String(cString: sqlite3_column_text(queryStatement, 5))
                let localPath = String(cString: sqlite3_column_text(queryStatement, 6))
                
                if let id = UUID(uuidString: idStr),
                   let status = VideoEntry.DownloadStatus(rawValue: statusStr) {
                    
                    let entry = VideoEntry(
                        id: id,
                        title: title,
                        url: url,
                        service: service,
                        date: Date(timeIntervalSince1970: dateVal),
                        status: status,
                        localPath: localPath.isEmpty ? nil : localPath
                    )
                    entries.append(entry)
                }
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return entries
    }
    
    func deleteEntry(id: UUID) {
        let deleteStatementString = "DELETE FROM VideoEntries WHERE id = ?;"
        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
    }
    
    func deleteEntries(before date: Date) {
        let deleteStatementString = "DELETE FROM VideoEntries WHERE date < ?;"
        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_double(deleteStatement, 1, date.timeIntervalSince1970)
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
    }
    
    func fetchRawLog(for id: UUID) -> String? {
        let queryString = "SELECT rawLog FROM VideoEntries WHERE id = ?;"
        var queryStatement: OpaquePointer?
        var log: String? = nil
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (id.uuidString as NSString).utf8String, -1, nil)
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(queryStatement, 0) {
                    log = String(cString: cStr)
                }
            }
        }
        sqlite3_finalize(queryStatement)
        return log
    }
    
    deinit {
        sqlite3_close(db)
    }
}
