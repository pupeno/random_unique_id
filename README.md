# Random Unique ID

[![Build Status](https://travis-ci.org/watu/random_unique_id.png?branch=master)](https://travis-ci.org/watu/random_unique_id)
[![Coverage Status](https://coveralls.io/repos/watu/random_unique_id/badge.png?branch=master)](https://coveralls.io/r/watu/random_unique_id?branch=master)
[![Code Climate](https://codeclimate.com/github/watu/random_unique_id.png)](https://codeclimate.com/github/watu/random_unique_id)
[![Inline docs](http://inch-ci.org/github/watu/random_unique_id.png)](http://inch-ci.org/github/watu/random_unique_id)
[![Gem Version](https://badge.fury.io/rb/random_unique_id.png)](http://badge.fury.io/rb/random_unique_id)
[![Dependency Status](https://gemnasium.com/watu/random_unique_id.svg)](https://gemnasium.com/watu/random_unique_id)

This gem will generate a random unique id for your active record records that you can use instead of their actual ID for
all external interactions with users. The goal is for you to be able to hide how many records you have, for business
purposes, but also to make IDs non-predictable.

This gem is built to work with Ruby 1.9, 2.0, 2.1 as well as with Rails 3.2, 4.0 and 4.1. All of these cases are
[continuously tested for](https://travis-ci.org/watu/random_unique_id).

## Installation

Add this line to your application's Gemfile:

    gem "random_unique_id"

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install random_unique_id

## Usage

The usage is very simple. For each record where you want to have a random id generated, add the following line to the
class:

    has_random_unique_id

For example:

    class Post < ActiveRecord::Base
      has_random_unique_id
    end

You need to also add a column, called `rid` of type string/varchar. It is recommended that you also add a unique index
on that column, for example:

    def up
      add_column :posts, :rid, :string
      add_index :posts, :rid, :unique
    end

The method `to_param` will be overridden to return the `rid` instead of the `id`. The method `belongs_to` gets extended
to define `_rid` methods similar to the `_id` method, like: `blog_rid` and `blog_rid=`. If you don't want to define
those pass `define_rid_method` as false, for example:

    class Post
      belongs_to :blog, define_rid_method: false
    end

Classes that have rids also get a method called `populate_random_unique_ids` to help you populate the rid of existing
records. For example:

    def up
      add_column :posts, :rid, :string
      add_index :posts, :rid, :unique
      say_with_time "Post.populate_random_unique_ids" do
        Post.reset_column_information
        Post.populate_random_unique_ids { print "."}
      end
    end

## Changelog

### Next version
- Started testing Ruby 2.1.2 and 2.1.3.
- Started testing Rails 4.1 (fixed some deprecation warnings).
- Improved documentation

### Version 0.2.1
- Internal refactorings.

### Version 0.2.0
- Added method populate_random_unique_ids.
- Improved documentation
- Started testing with Ruby 2.1.

### Version 0.1.0
- Initial release of the code extracted from [Watu](http://github.com/watu).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am "Add some feature"`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
