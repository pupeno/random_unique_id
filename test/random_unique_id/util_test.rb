# Copyright © 2014, Watu

require_relative "../test_helper"

require "random_unique_id"
require "random_unique_id/util"

class RandomUniqueId::UtilTest < MiniTest::Unit::TestCase
  should "raise an exception for unknown adapters" do
    sql_connection = stub("connection", adapter_name: "dBASE")
    ActiveRecord::Base.expects(:connection).returns(sql_connection)
    assert_raises RuntimeError do
      RandomUniqueId::Util.set_initial_ids
    end
  end

  should "set initial ids in PostgreSQL" do
    sql_connection = mock("connection")
    sql_connection.stubs(:adapter_name).returns("PostgreSQL")
    sequences = ["sequence_1", "sequence_2"]
    sql_connection.expects(:select_values).with("SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'").returns(sequences)
    sql_connection.expects(:select_values).with("SELECT nextval('sequence_1')").returns(["1"])
    sql_connection.expects(:execute).with("SELECT setval('sequence_1', 10000)")
    sql_connection.expects(:select_values).with("SELECT nextval('sequence_2')").returns(["20000"])
    sql_connection.expects(:execute).with("SELECT setval('sequence_2', 20000)")
    ActiveRecord::Base.expects(:connection).returns(sql_connection)
    RandomUniqueId::Util.set_initial_ids
  end
end