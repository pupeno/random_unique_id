# encoding: UTF-8
# Copyright © 2011, 2012, 2013, 2014, Watu

require "random_unique_id/version"
require "securerandom"
require "active_support"
require "active_record"

module RandomUniqueId
  extend ActiveSupport::Concern

  module ClassMethods
    # Mark a model as containing a random unique id. A field called rid of type string is required. It's recommended
    # that it's indexed and unique. For example, you could add it to a migration like this:
    #   def up
    #     add_column :posts, :rid, :string
    #     add_index :posts, :rid, :unique
    #   end
    #
    # and then to the model like this:
    #   class Post
    #     has_random_unique_id
    #     # ... other stuff
    #   end
    def has_random_unique_id
      validates :rid, presence: true, uniqueness: true
      before_validation :generate_random_unique_id, if: Proc.new { |r| r.rid.blank? }
      define_method(:to_param) { rid }
    end

    def belongs_to(*attrs)
      define_rid_method = attrs[1].try(:delete, :rid)
      super.tap do
        if define_rid_method != false
          rel_name = attrs[0]
          rel = reflections[rel_name]

          return if rel.options[:polymorphic] # If we don't know the class, we cannot find the record by rid.

          class_name = rel.options[:class_name] || rel_name.to_s.classify
          klass = class_name.constantize

          if klass.attribute_names.include? "rid"
            define_method("#{rel_name}_rid") do
              self.send(rel_name).try(:rid)
            end

            define_method("#{rel_name}_rid=") do |rid|
              record = klass.find_by_rid(rid)
              self.send("#{rel_name}=", record)
              record
            end
          end
        end
      end
    end

    # Populate all the blank rids in a table. This is useful when adding rids to a table that already has data in it.
    # For example:
    #   def up
    #     add_column :posts, :rid, :string
    #     add_index :posts, :rid, :unique
    #     say_with_time "Post.populate_random_unique_ids" do
    #       Post.reset_column_information
    #       Post.populate_random_unique_ids { print "."}
    #     end
    #   end
    #
    # This method uses update_column to avoid running validations and callbacks. It will not change existing rids, so
    # it's safe to call several times and a failure (even without a transaction) is not catastrophic.
    def populate_random_unique_ids
      find_each do |record|
        rid_just_populated = false
        if record.rid.blank?
          record.generate_random_unique_id
          record.update_column(:rid, record.rid)
          rid_just_populated = true
        end
        yield(record, rid_just_populated) if block_given?
      end
    end

  end

  def generate_random_unique_id(n=5, field="rid")
    # Find the topmost class before ActiveRecord::Base so that when we do queries, we don't end up with type=Whatever in the where clause.
    klass = self.class
    self.class.ancestors.each do |k|
      if k == ActiveRecord::Base
        break # we reached the bottom of this barrel
      end
      if k.is_a? Class
        klass = k
      end
    end

    begin
      self.send("#{field}=", RandomUniqueId.generate_random_id(n))
      n += 1
    end while klass.unscoped.where(field => self.send(field)).exists?
  end

  def self.generate_random_id(n=10)
    # IMPORTANT: don't ever generate dashes or underscores in the RIDs as they are likely to end up in the UI in Rails
    # and they'll be converted to something else by jquery ujs or something like that.
    generated_rid = ""
    while generated_rid.length < n
      generated_rid = (generated_rid + SecureRandom.urlsafe_base64(n * 3).downcase.gsub(/[^a-z0-9]/, ""))[0..(n-1)]
    end
    return generated_rid
  end
end

ActiveRecord::Base.send(:include, RandomUniqueId)
