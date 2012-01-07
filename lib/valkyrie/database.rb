require "sequel"
require "valkyrie"

class Valkyrie::Database

  Sequel.extension :schema_to_hash
  Sequel.extension :pagination

  attr_reader :connection
  attr_accessor :tables

  def initialize(uri, opts)
    @connection = Sequel.connect(uri)
    @opts = opts
    Sequel::MySQL.convert_invalid_date_time = nil if @connection.adapter_scheme == :mysql
  end

  def transfer_to(db, &cb)
    cb.call(:tables, tables.length)
    tables.each do |name|
      cb.call(:table, [name, connection[name].count])
      transfer_table(name, db, &cb)
    end
  end

  def transfer_table(name, db, &cb)
    db.connection.drop_table(name) if db.connection.table_exists?(name)
    db.connection.hash_to_schema(name, connection.schema_to_hash(name), &cb)

    columns = connection.schema(name).map(&:first)

    unless @opts[:no_data]
      dataset = connection[name.to_sym]

      cb.call(:rows)
      buffer = []
      count = 0

      dataset.each do |row|
        buffer << row
        count  += 1

        if buffer.length >= @opts[:buffer_length]
          cb.call(:row, count)
          send_rows(db, name, columns, buffer)
          buffer.clear
          count=0
        end
      end

      cb.call(:row, count)
      send_rows(db, name, columns, buffer) if buffer.length > 0
    end

    cb.call(:end)
    columns
  end

  def send_rows(db, name, columns, rows)
    data = rows.map { |row| columns.map { |c| row[c] } }

    begin
      db.connection[name].insert_multiple data
    rescue
      puts "Insert into #{name} failed: #{data.inspect}"
      raise
    end
  end

  def tables
    @tables ||= connection.tables
  end

end

