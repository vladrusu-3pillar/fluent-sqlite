import Fluent

public class SQLiteDriver: Fluent.Driver {
    let database: SQLite!
    public static var databaseFilePath = ""
    
    public init() throws {
        self.database = try SQLite(path: SQLiteDriver.databaseFilePath)
    }
    
    public func execute<T: Model>(query: Query<T>) throws -> [[String: Value]] {
        let sql = SQL(query: query)
        let sqlStatement = sql.statement
        
        let results: [SQLite.Result.Row]
        do {
            if sql.values.count > 0 {
                var position = 1
                results = try self.database.execute(sqlStatement) { statementPointer in
                    for value in sql.values {
                        
                        if let int = value.int {
                            try self.database.bind(Int32(int), position: position, statementPointer: statementPointer)
                        } else if let double = value.double {
                            try self.database.bind(double, position: position, statementPointer: statementPointer)
                        } else {
                            try self.database.bind(value.string, position: position, statementPointer: statementPointer)
                        }
                        position += 1
                    }
                }
                
            } else {
                results = try self.database.execute(sql.statement)
            }
            
            var data: [[String: Value]] = []
            for row in results {
                var t: [String: Value] = [:]
                for (k, v) in row.data {
                    t[k] = v as String
                }
                data.append(t)
            }
            
            return data
        } catch SQLiteError.ConnectionException {
            throw DriverError.Generic(message: "Connection Lost or failure to establish a connection")
        } catch SQLiteError.FailureToBind {
            throw DriverError.Generic(message: "Value to column bind failure")
        } catch SQLiteError.IndexOutOfBoundsException {
            throw DriverError.Generic(message: "Index out of bounds")
        } catch SQLiteError.SQLException {
            throw DriverError.Generic(message: "SQL statement invalid or cannot be executed")
        }
    }
    
}
