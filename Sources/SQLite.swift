#if os(Linux)
    import CSQLiteLinux
#else
    import CSQLiteMac
#endif

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteError: ErrorProtocol {
    case ConnectionException, SQLException, IndexOutOfBoundsException, FailureToBind
}

class SQLite {
    typealias BindHandler = ((statementPointer:UnsafeMutablePointer<OpaquePointer>) throws -> ())
    var database: OpaquePointer = nil
    
    init(path: String) throws {
        let code = sqlite3_open_v2(path, &self.database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        if code != SQLITE_OK {
            print(code)
            sqlite3_close(self.database)
            throw SQLiteError.ConnectionException
        }
    }
    
    func close() {
        sqlite3_close(self.database)
    }
    
    class Result {
        class Row {
            var data: [String: String]
            
            init() {
                self.data = [:]
            }
        }
        
        var rows: [Row]
        
        init() {
            self.rows = []
        }
    }
    
    func execute(statement: String, bindHandler: BindHandler) throws -> [Result.Row] {
        let statementPointer = UnsafeMutablePointer<OpaquePointer>.init(allocatingCapacity: 1)
        if sqlite3_prepare_v2(self.database, statement, -1, statementPointer, nil) != SQLITE_OK {
            print("preparing failed")
            return []
        }
        
        try bindHandler(statementPointer: statementPointer)
        let result = Result()
        while sqlite3_step(statementPointer.pointee) == SQLITE_ROW {
            
            let row = Result.Row()
            let columnCount = sqlite3_column_count(statementPointer.pointee)
            
            for i in 0..<columnCount {
                
                var value:String?
                if sqlite3_column_text(statementPointer.pointee, i) != nil {
                    value = String(cString: UnsafePointer<CChar>(sqlite3_column_text(statementPointer.pointee, i)))
                }
                var name:String?
                if sqlite3_column_name(statementPointer.pointee, i) != nil {
                    name = String(cString: UnsafePointer<CChar>(sqlite3_column_name(statementPointer.pointee, i)))
                }
                
                if let value = value,
                    name = name {
                    row.data[name] = value
                }
            }
            
            result.rows.append(row)
        }
        
        let status = sqlite3_finalize(statementPointer.pointee)
        if status != SQLITE_OK {
            print(errorMessage())
            print("Preparing statement failed! status \(status)")
            return []
        }
        
        return result.rows
    }
    
    func execute(statement: String) throws -> [Result.Row] {
        let resultPointer = UnsafeMutablePointer<Result>.init(allocatingCapacity: 1)
        var result = Result()
        resultPointer.initializeFrom(&result, count: 1)
        
        let code = sqlite3_exec(self.database, statement, { resultVoidPointer, columnCount, values, columns in
            let resultPointer = UnsafeMutablePointer<Result>(resultVoidPointer)
            let result = resultPointer.pointee
            
            let row = Result.Row()
            for i in 0 ..< Int(columnCount) {
                
                var value:String?
                if values[i] != nil {
                    value = String(cString: UnsafePointer<CChar>(values[i]))
                }
                var column:String?
                if columns[i] != nil {
                    column = String(cString: UnsafePointer<CChar>(columns[i]))
                }
                
                if let value = value,
                    column = column {
                    row.data[column] = value
                }
            }
            
            result.rows.append(row)
            return 0
            }, resultPointer, nil)
        
        if code != SQLITE_OK {
            print(errorMessage())
            throw SQLiteError.SQLException
        }
        
        return result.rows
    }
    
    func errorMessage() -> String {
        let error = String(sqlite3_errmsg(self.database)) ?? ""
        return error
    }
    
    func reset(statementPointer: OpaquePointer) {
        sqlite3_reset(statementPointer)
        sqlite3_clear_bindings(statementPointer)
    }
    
    func bind(value: String, position: Int, statementPointer:UnsafeMutablePointer<OpaquePointer>) throws {
        let status = sqlite3_bind_text(statementPointer.pointee, Int32(position), value, -1, SQLITE_TRANSIENT)
        if status != SQLITE_OK {
            print(errorMessage())
            throw SQLiteError.FailureToBind
        }
    }
    
    func bind(value: Int32, position: Int, statementPointer:UnsafeMutablePointer<OpaquePointer>) throws {
        if sqlite3_bind_int(statementPointer.pointee, Int32(position), value) != SQLITE_OK {
            print(errorMessage())
            throw SQLiteError.FailureToBind
        }
    }
    
    func bind(value: Int64, position: Int, statementPointer:UnsafeMutablePointer<OpaquePointer>) throws {
        if sqlite3_bind_int64(statementPointer.pointee, Int32(position), value) != SQLITE_OK {
            print(errorMessage())
            throw SQLiteError.FailureToBind
        }
    }
    
    func bind(value: Double, position: Int, statementPointer:UnsafeMutablePointer<OpaquePointer>) throws {
        if sqlite3_bind_double(statementPointer.pointee, Int32(position), value) != SQLITE_OK {
            print(errorMessage())
            throw SQLiteError.FailureToBind
        }
    }
    
    func bind(value: Bool, position: Int, statementPointer:UnsafeMutablePointer<OpaquePointer>) throws {
        if sqlite3_bind_int(statementPointer.pointee, Int32(position), value ? 1 : 0) != SQLITE_OK {
            print(errorMessage())
            throw SQLiteError.FailureToBind
        }
    }
    
    func generateTestData() {
        do {
            try self.execute("CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL);")
            try self.execute("INSERT INTO users (id, name) VALUES (NULL, 'Tanner');")
            try self.execute("INSERT INTO users (id, name) VALUES (NULL, 'Jill');")
        } catch {
            print("Test Execution Error")
        }
    }
    
}