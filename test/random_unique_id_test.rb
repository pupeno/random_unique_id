# encoding: UTF-8
# Copyright © 2011, 2012, 2013, 2014, 2015, Watu

require_relative "test_helper"

require "random_unique_id"

ActiveRecord::Schema.define(version: 0) do
  create_table :blogs do |t|
    t.string :rid
    t.string :name
  end
  add_index :blogs, :rid, unique: true

  create_table :posts do |t|
    t.string :rid
    t.string :type
    t.integer :blog_id
  end
  add_index :posts, :rid, unique: true

  create_table :comments do |t|
    t.string :random_id
    t.string :text
    t.integer :post_id
  end
  add_index :comments, :random_id, unique: true

  create_table :post_views do |t|
    t.string :rid
    t.string :ip_address
    t.integer :post_id
  end
  add_index :post_views, :rid # NOT unique, for performance, it'll store UUIDs so we don't need to check
end

class Blog < ActiveRecord::Base
  has_many :posts
  has_random_unique_id
end

class BlogWithInvalidGenerationMethod < ActiveRecord::Base
  self.table_name = "blogs"
  has_random_unique_id(random_generation_method: :invalid) # Used to test the exception when you specify the wrong method
end

original_config = RandomUniqueId.config
RandomUniqueId.config(random_generation_method: :uuid)

class BlogWithUuid < ActiveRecord::Base
  self.table_name = "blogs"
  has_random_unique_id
end

RandomUniqueId.config(random_generation_method: :short, min_rid_length: 12)

class BlogWithLongRid < ActiveRecord::Base
  self.table_name = "blogs"
  has_random_unique_id
end

RandomUniqueId.config(original_config)

class Post < ActiveRecord::Base
  belongs_to :blog
  has_random_unique_id
end

class TextPost < Post
end

class ImagePost < Post
end

class Comment < ActiveRecord::Base
  belongs_to :post
  has_random_unique_id(field: :random_id, min_rid_length: 10) # Comments have longer RIDs, since it's a big table and we were getting lots of collissions
end

class PostView < ActiveRecord::Base
  belongs_to :post
  has_random_unique_id(random_generation_method: :uuid) # Post Views have UUIDs instead of RIDs, since the table is ginormous, so it can't check for existence every time.
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
      RandomUniqueId.expects(:generate_short_random_id).with(5).returns(@text_post.rid)
      new_rid = @text_post.rid + "i"
      RandomUniqueId.expects(:generate_short_random_id).with(6).returns(new_rid)

      new_record = TextPost.create! # No exception should be raised.
      assert_equal new_rid, new_record.rid
    end

    should "resolve random id collision in different classes of the same table (due to STI)" do
      # Mock RandomUniqueId to return a collision on the first call, and hopefully a non collision on the second, expecting n to grow by one.
      RandomUniqueId.expects(:generate_short_random_id).with(5).returns(@text_post.rid)
      new_rid = @text_post.rid + "i"
      RandomUniqueId.expects(:generate_short_random_id).with(6).returns(new_rid)

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

    should "populate a table with rids" do
      # Create a bunch of blogs without rid by manually inserting them into the table.
      rid_less_records = 10
      5.times { Blog.create! }
      existing_rids = Blog.all.map(&:rid).compact
      rid_less_records.times { Blog.connection.execute("INSERT INTO blogs (name) VALUES ('Blag')") }
      assert_equal rid_less_records, Blog.where(rid: nil).count # Just to be sure this test is being effective.

      rids_populated = 0
      Blog.populate_random_unique_ids { |_, rid_just_populated| rids_populated += 1 if rid_just_populated }
      assert_equal rid_less_records, rids_populated
      assert_equal 0, Blog.where(rid: nil).count
      assert_equal existing_rids.count, Blog.where(rid: existing_rids).count # Make sure the existing rids where not touched.
    end

    should "populate a table with rids with custom field name" do
      # Create a bunch of comments without rid by manually inserting them into the table
      rid_less_records = 10
      blog = Blog.create!
      post = Post.create!(blog: blog)
      5.times { Comment.create!(post: post) }
      existing_rids = Comment.all.map(&:random_id).compact
      rid_less_records.times { Comment.connection.execute("INSERT INTO comments (post_id) VALUES (#{post.id})") }
      assert_equal rid_less_records, Comment.where(random_id: nil).count # Just to be sure this test is being effective.

      rids_populated = 0
      Comment.populate_random_unique_ids { |_, rid_just_populated| rids_populated += 1 if rid_just_populated }
      assert_equal rid_less_records, rids_populated
      assert_equal 0, Comment.where(random_id: nil).count
      assert_equal existing_rids.count, Comment.where(random_id: existing_rids).count # Make sure the existing rids where not touched.
    end
  end

  context "With an invalid generation method" do
    should "Raise exception on RID geneartion" do
      assert_raises RuntimeError do
        BlogWithInvalidGenerationMethod.create!
      end
    end
  end

  # Tests for configuration options, both global and model overrides
  context "With a global configuration for UUIDs" do
    should "generate UUID" do
      blog = BlogWithUuid.create!
      assert_match /(\w{8}(-\w{4}){3}-\w{12}?)/, blog.rid
    end
  end

  context "With a global configuration for long RIDs" do
    should "generate long RID" do
      blog = BlogWithLongRid.create!
      assert blog.rid.length >= 12, "RID must be at least 12 chars long"
      assert !(blog.rid =~ /(\w{8}(-\w{4}){3}-\w{12}?)/), "RID must not be a UUID"
    end
  end

  context "With models that have overrides for RID configuration" do
    should "Generate short RID for normal model" do
      blog = Blog.create!
      assert_equal 5, blog.rid.length
    end

    should "Generate long RID for model that requested min_rid_length" do
      comment = Comment.create!
      assert_equal 10, comment.random_id.length
    end

    should "Generate UUID for model that requested UUID random_generation_method" do
      postview = PostView.create!
      assert_match /(\w{8}(-\w{4}){3}-\w{12}?)/, postview.rid
    end
  end
end
