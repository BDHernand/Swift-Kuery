/**
 Copyright IBM Corporation 2016
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

// MARK: Insert

/// The SQL INSERT statement.
public struct Insert: Query {
    /// The table to insert rows.
    public let table: Table
    
    /// An array of columns to insert. If not specified, values of all the columns have to be provided.
    public let columns: [Column]?
    
    /// An array of rows (values to insert in each row).
    public private (set) var values: [[Any]]?
    
    /// A `Returning` enum value corresponding to the SQL RETURNING clause.
    public private (set) var returningClause: Returning?
    
    /// The select query that retrieves the rows to insert (for INSERT INTO SELECT).
    public private (set) var query: Select?
    
    private var syntaxError = ""
    
    /// Initialize an instance of Insert.
    ///
    /// - Parameter into: The table to insert rows.
    /// - Parameter columns: An optional array of columns to insert. If nil, values of all the columns have to be provided.
    /// - Parameter values: An array containg the row to insert.
    public init(into table: Table, columns: [Column]?, values: [Any]) {
        self.columns = columns
        var valuesToInsert = [[Any]]()
        valuesToInsert.append(values)
        self.values = valuesToInsert
        self.table = table
        if let tableColumns = self.columns, tableColumns.count != values.count {
            syntaxError = "Values count doesn't match column count. "
        }
    }
    
    /// Initialize an instance of Insert.
    ///
    /// - Parameter into: The table to insert rows.
    /// - Parameter columns: An optional array of columns to insert. If not specified, values of all the columns have to be provided.
    /// - Parameter values: An array of rows (values to insert in each row).
    public init(into table: Table, columns: [Column]?=nil, rows: [[Any]]) {
        self.columns = columns
        self.values = rows
        self.table = table
        if let tableColumns = self.columns {
            for (index, row) in rows.enumerated() {
                if tableColumns.count != row.count {
                    syntaxError += "Values count in row number \(index) doesn't match column count. "
                }
            }
        }
    }
    
    /// Initialize an instance of Insert.
    ///
    /// - Parameter into: The table to insert rows.
    /// - Parameter values: A list of values (the row) to insert.
    public init(into table: Table, values: Any...) {
        self.init(into: table, columns: nil, values: values)
    }
    
    /// Initialize an instance of Insert.
    ///
    /// - Parameter into: The table to insert rows.
    /// - Parameter valueTuples: An array of (column, value) pairs to insert.
    public init(into table: Table, valueTuples: [(Column, Any)]) {
        var columnsArray = Array<Column>()
        var valuesArray = Array<Any>()
        for (column, value) in valueTuples {
            columnsArray.append(column)
            valuesArray.append(value)
        }
        self.init(into: table, columns: columnsArray, values: valuesArray)
    }
    
    /// Initialize an instance of Insert.
    ///
    /// - Parameter into: The table to insert rows.
    /// - Parameter valueTuples: A list of (column, value) pairs to insert.
    public init(into table: Table, valueTuples: (Column, Any)...) {
        self.init(into: table, valueTuples: valueTuples)
    }
    
    /// Initialize an instance of Insert.
    ///
    /// - Parameter into: The table to insert rows.
    /// - Parameter columns: An optional array of columns to insert. If nil, values of all the columns have to be provided.
    /// - Parameter query: The select query that retrieves the rows to insert.
    public init(into table: Table, columns: [Column]?=nil, _ query: Select) {
        self.columns = columns
        self.table = table
        self.query = query
        if let tableColumns = self.columns, let selectColumns = query.fields,
            tableColumns.count != selectColumns.count {
            syntaxError = "Number of columns in Select doesn't match column count. "
        }
    }
    
    /// Build the query using `QueryBuilder`.
    ///
    /// - Parameter queryBuilder: The QueryBuilder to use.
    /// - Returns: A String representation of the query.
    /// - Throws: QueryError.syntaxError if query build fails.
    public func build(queryBuilder: QueryBuilder) throws -> String {
        if syntaxError != "" {
            throw QueryError.syntaxError(syntaxError)
        }
        var result = try "INSERT INTO " + table.build(queryBuilder: queryBuilder) + " "
        if let columns = columns, columns.count != 0 {
            result += "(\(columns.map { $0.name }.joined(separator: ", "))) "
        }
        if let values = values {
            result += "VALUES ("
            result += try "\(values.map { "\(try $0.map { try packType($0, queryBuilder: queryBuilder) }.joined(separator: ", "))" }.joined(separator: "), ("))"
            result += ")"
        }
        else if let query = query {
            result += try query.build(queryBuilder: queryBuilder)
        }
        else {
            throw QueryError.syntaxError("Insert query doesn't have any values to insert.")
        }
        if let returning = returningClause {
            result += try " RETURNING " + returning.build(queryBuilder: queryBuilder)
        }
        result = updateParameterNumbers(query: result, queryBuilder: queryBuilder)
        return result
    }
    
    /// Add an SQL RETURNING clause to the Insert statement.
    ///
    /// - Parameter columns: An optional array of `Column`s to be returned. If not specified, all columns are returned.
    /// - Returns: A new instance of Insert.
    public func returning(_ columns: [Column]?=nil) -> Insert {
        var new = self
        if returningClause != nil {
            new.syntaxError += "Multiple returning clauses. "
        }
        else {
            if let columns = columns {
                new.returningClause = Returning.columns(columns)
            }
            else {
                new.returningClause = Returning.all
            }
        }
        return new
    }
    
    /// Add an SQL RETURNING clause to the Insert statement.
    ///
    /// - Parameter columns: A list of `Column`s to be returned.
    /// - Returns: A new instance of Insert.
    public func returning(_ columns: Column...) -> Insert {
        var new = self
        if returningClause != nil {
            new.syntaxError += "Multiple returning clauses. "
        }
        else {
            new.returningClause = Returning.columns(columns)
        }
        return new
    }
}
