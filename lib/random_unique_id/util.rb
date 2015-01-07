# Copyright © 2014, Watu

# Some utilities that might be useful if you are using RandomUniqueId. This file needs to be explicitely included:
#
#   require "random_unique_id/util"
module RandomUniqueId::Util
  # Set the initial automatic ids on the database (also known as sequences) to a higher number than 1. The reason to use
  # this is in case you want to test for id leakage in HTML. For example, you create a blog post, display it, and search
  # the HTML for the id of the blog post, author, featured image, and so on. If these ids are low, like 1 or 10, the
  # likelihood of false positives is very high, but if they are larger numbers, like 10001, then it becomes very
  # unlikely (but not impossible).
  #
  # @param [Hash] options
  # @option options [Boolean] :verbose whether to print messages to the console about what's going on or not.
  # @option options [Integer] :initial_id initial id at which the sequences will be set.
  def self.set_initial_ids(options={})
    options.reverse_merge!(verbose: false, initial_id: 10000)
    verbose = options[:verbose]
    initial_id = options[:initial_id]

    sql_connection = ActiveRecord::Base.connection
    case sql_connection.adapter_name
      when "PostgreSQL"
        puts "==  Setting initial ids to #{initial_id} or the next available one".ljust(79, "=") if verbose
        sequences = sql_connection.select_values("SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'")
        sequences.each do |sequence|
          print "-- Setting initial id for #{sequence} to..." if verbose
          next_id = [initial_id, sql_connection.select_values("SELECT nextval('#{sequence}')").first.to_i].max
          print "#{next_id}..." if verbose
          sql_connection.execute("SELECT setval('#{sequence}', #{next_id})")
          puts " done." if verbose
        end
        puts "==  Setting initial ids to #{initial_id} (done)  ".ljust(79, "=") if verbose
      else
        raise "Don't know how to set initial ids for #{sql_connection.adapter_name}. Would you like to contribute? https://github.com/watu/random_unique_id"
    end
  end
end
