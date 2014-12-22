# encoding: UTF-8
# Copyright © 2011, 2012, 2013, 2014, Watu

require "random_unique_id/version"
require "securerandom"
require "active_support"
require "active_record"

module RandomUniqueId
  extend ActiveSupport::Concern

  # Collection of methods that will end as class methods of ActiveRecord::Base.
  #
  # @see ActiveSupport::Concern
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

    # Augment the ActiveRecord belongs_to to also define rid accessors. For example: if you blog post belongs_to an
    # author, on top of the methods #author, #author=, #author_id and #author_id=, it'll also have #author_rid and
    # #author_rid= that allow you to retrieve the RID of the author or set another author by using the RID.
    #
    # @param attrs [Array] same as the parameters for ActiveRecord::Associations::ClassMethods.belongs_to except that
    #   passing rid: false will prevent the rid accessors from beign defined.
    # @see ActiveRecord::Associations::ClassMethods.belongs_to
    def belongs_to(*attrs)
      define_rid_method = attrs[1].try(:delete, :rid)
      super.tap do
        if define_rid_method != false
          relationship_name = attrs[0]
          rel = reflections[relationship_name] || reflections[relationship_name.to_s]

          return if rel.options[:polymorphic] # If we don't know the class, we cannot find the record by rid.

          class_name = rel.options[:class_name] || relationship_name.to_s.classify
          related_class = class_name.constantize
          define_rid_accessors(related_class, relationship_name) if related_class.attribute_names.include? "rid"
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

    private

    # Defines the setter and getter for the RID of a relationship.
    #
    # @param related_class [Class] class in which the RID methods are going to be defined.
    # @param relationship_name [String] name of the relationship for which the RID methods are going to be defined.
    # @see RandomUniqueId::ClassMethods.belongs_to
    def define_rid_accessors(related_class, relationship_name)
      define_method("#{relationship_name}_rid") do
        self.send(relationship_name).try(:rid)
      end

      define_method("#{relationship_name}_rid=") do |rid|
        record = related_class.find_by_rid(rid)
        self.send("#{relationship_name}=", record)
        record
      end
    end
  end

  # Generate and store the random unique id for the object.
  #
  # @param n [Integer] how long should the random string be.
  # @param field [String] name of the field that contains the rid.
  # @return [String] the random string.
  # @see RandomUniqueId::ClassMethods#has_random_unique_id
  # @see RandomUniqueId.generate_random_id
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

  # By a cunning use of SecureRandom.urlsafe_base64, quickly generate an alphanumeric random string.
  #
  # @param n [Integer] how long should the random string be.
  # @return [String] the random string.
  # @see RandomUniqueId#generate_random_unique_id
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
