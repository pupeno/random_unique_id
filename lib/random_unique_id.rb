# encoding: UTF-8
# Copyright © 2011, 2012, 2013, 2014, Watu

require "random_unique_id/version"
require "securerandom"
require "active_support"
require "active_record"

module RandomUniqueId
  extend ActiveSupport::Concern

  @@config = nil

  # The global configuration for RandomUniqueID.
  # Set it in initializers
  #
  #     RandomUniqueId.config(field: :rid,
  #                           random_generation_method: :short,
  #                           min_rid_length: 5)
  #
  # @param [Hash] options
  # @option options [Symbol] field the name of the field where the random unique id is stored.
  # @option options [Symbol] random_generation_method the method to generate random IDs, `:short` or `:uuid`.
  #   `:short` will generate a short-ish random ID, and check that it is unique
  #   `:uuid` will generate a UUID, and skip the check. This is better for performance, and bad for readability of IDs
  # @option options [FixNum] min_rid_length the minimum length RandomUniqueID will generate. Defaults to 5
  # @return [Hash] the configuration.
  def self.config(options={})
    defaults = {field: :rid, random_generation_method: :short, min_rid_length: 5}
    @@config ||= defaults
    @@config = @@config.merge(options)
    @@config
  end

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
    #
    # @param options [Hash] generation options, same as RandomUniqueID.config, in case the generation method or minimum
    #   length needs to be overridden for one specific model
    def has_random_unique_id(options={})
      options = RandomUniqueId.config.merge(options)

      validates(options[:field], presence: true)
      validates(options[:field], uniqueness: true) if options[:random_generation_method] != :uuid # If we're generating UUIDs, don't check for uniqueness

      before_validation :populate_rid_field, if: Proc.new { |r| r.send(options[:field]).blank? }
      define_method(:to_param) { send(options[:field]) }
      define_method(:random_unique_id_options) { options } # I don't think this is the best way to store this, but I didn't find a better one.
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
        if record.send(record.random_unique_id_options[:field]).blank?
          record.populate_rid_field
          record.update_column(record.random_unique_id_options[:field], record.send(record.random_unique_id_options[:field]))
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
        self.send(relationship_name).try(random_unique_id_options[:field])
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
  # @param length [Integer] how long should the random string be. Only applicable for `:short` type.
  # @param field [String] name of the field that contains the rid.
  # @return [String] the random string.
  # @see RandomUniqueId::ClassMethods#has_random_unique_id
  # @see RandomUniqueId.generate_random_id
  def populate_rid_field(length=random_unique_id_options[:min_rid_length], field=random_unique_id_options[:field])
    case random_unique_id_options[:random_generation_method]
      when :short
        self.send("#{field}=", generate_short_random_unique_id(length, field))
      when :uuid
        self.send("#{field}=", RandomUniqueId.generate_uuid)
      else
        raise "Invalid random generation method: #{self.random_unique_id_options[:random_generation_method]}"
    end
  end

  # Generate random ids, increasing their size, until one is found that is not used for another record in the database.
  # @param length [Integer] how long should the random string be.
  # @param field [String] name of the field that contains the rid.
  def generate_short_random_unique_id(length, field)
    potential_unique_random_id = nil
    begin
      potential_unique_random_id = RandomUniqueId.generate_short_random_id(length)
      length += 1
    end while topmost_model_class.unscoped.where(field => potential_unique_random_id).exists?
    potential_unique_random_id
  end

  # Find the topmost class before ActiveRecord::Base so that when we do queries, we don't end up with type=Whatever in
  # the where clause.
  # @return [Class] the class object
  def topmost_model_class
    @topmost_model_class ||= begin
      klass = self.class
      self.class.ancestors.select { |k| k.is_a? Class }.each do |k|
        if k == ActiveRecord::Base
          return klass
        end
        klass = k
      end
    end
  end

  # By a cunning use of SecureRandom.urlsafe_base64, quickly generate an alphanumeric random string.
  #
  # @param length [Integer] how long should the random string be.
  # @return [String] the random string.
  # @see RandomUniqueId#populate_rid_field
  def self.generate_short_random_id(length=10)
    # IMPORTANT: don't ever generate dashes or underscores in the RIDs as they are likely to end up in the UI in Rails
    # and they'll be converted to something else by jquery ujs or something like that.
    generated_rid = ""
    while generated_rid.length < length
      generated_rid = (generated_rid + SecureRandom.urlsafe_base64(length * 3).downcase.gsub(/[^a-z0-9]/, ""))[0..(length-1)]
    end
    return generated_rid
  end

  # Generate a UUID. Just a wrapper around SecureRandom.uuid
  # @return [String] the new UUID.
  # @see RandomUniqueId#populate_rid_field
  def self.generate_uuid
    SecureRandom.uuid
  end
end

ActiveRecord::Base.send(:include, RandomUniqueId)
