require "valkyrie/database"
require "valkyrie/progress_bar"
require 'valkyrie/trollop'

class Valkyrie::CLI

  def self.start(*args)
    opts = Trollop::options(args) do
      opt :tables, "Tables to copy", :type => :string
      opt :buffer_length, "Number of rows to insert at once", :default => 500
    end
    
    url1 = args.shift
    url2 = args.shift

    unless url1 && url2
      puts "valkyrie FROM TO"
      exit 1
    end

    db1 = Valkyrie::Database.new(url1, opts)
    db1.tables = opts[:tables].split(",").map(&:to_sym) if opts[:tables]
    db2 = Valkyrie::Database.new(url2, opts)

    progress = nil

    db1.transfer_to(db2) do |type, data|
      case type
        when :tables then puts "Transferring #{data} tables:"
        when :table  then progress = Valkyrie::ProgressBar.new(data.first, data.last, $stdout)
        when :row    then progress.inc(data)
        when :end    then progress.finish
      end
    end
  rescue Interrupt
    puts
    puts "ERROR: Transfer aborted by user"
  end

end
