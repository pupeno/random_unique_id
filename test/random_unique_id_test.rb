# encoding: UTF-8
# Copyright © 2011, 2012, 2013, 2014, Watu

require_relative "test_helper"

require "random_unique_id"

ActiveRecord::Schema.define(version: 0) do
  create_table :blogs do |t|
    t.string :rid
  end
  add_index :blogs, :rid, unique: true

  create_table :posts do |t|
    t.string :rid
    t.string :type
    t.integer :blog_id
  end
  add_index :posts, :rid, unique: true
end

class Blog < ActiveRecord::Base
  has_many :posts
  has_random_unique_id
end

class Post < ActiveRecord::Base
  belongs_to :blog
  has_random_unique_id
end

class TextPost < Post
end

class ImagePost < Post
end


class RandomUniqueIdTest < MiniTest::Unit::TestCase
  context "With a record with random id" do
    setup { @text_post = TextPost.create! }

    should "generate a random id" do
      assert @text_post.rid
    end

    should "return random id as param" do
      assert_equal @text_post.rid, @text_post.to_param
    end

    should "resolve random id collision" do
      # Mock RandomUniqueId to return a collision on the first call, and hopefully a non collision on the second, expecting n to grow by one.
      RandomUniqueId.expects(:generate_random_id).with(5).returns(@text_post.rid)
      new_rid = @text_post.rid + "i"
      RandomUniqueId.expects(:generate_random_id).with(6).returns(new_rid)

      new_record = TextPost.create! # No exception should be raised.
      assert_equal new_rid, new_record.rid
    end

    should "resolve random id collision in different classes of the same table (due to STI)" do
      # Mock RandomUniqueId to return a collision on the first call, and hopefully a non collision on the second, expecting n to grow by one.
      RandomUniqueId.expects(:generate_random_id).with(5).returns(@text_post.rid)
      new_rid = @text_post.rid + "i"
      RandomUniqueId.expects(:generate_random_id).with(6).returns(new_rid)

      new_record = ImagePost.create! # No exception should be raised.
      assert_equal new_rid, new_record.rid
    end

    should "have automatic *_rid= and *_rid methods" do
      blog = Blog.create!

      @text_post.blog_rid = blog.rid
      @text_post.save!

      assert_equal blog, @text_post.blog
      assert_equal blog.rid, @text_post.blog_rid
    end
  end
end
