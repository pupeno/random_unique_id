# Random Unique ID

[![Build Status](https://travis-ci.org/watu/random_unique_id.png?branch=master)](https://travis-ci.org/watu/random_unique_id)
[![Coverage Status](https://coveralls.io/repos/watu/random_unique_id/badge.png?branch=master)](https://coveralls.io/r/watu/random_unique_id?branch=master)
[![Code Climate](https://codeclimate.com/github/watu/random_unique_id.png)](https://codeclimate.com/github/watu/random_unique_id)
[![Gem Version](https://badge.fury.io/rb/random_unique_id.png)](http://badge.fury.io/rb/random_unique_id)

This gem will generate a random unique id for your active record records that you can use instead of their actual ID for
all external interactions with users. The goal is for you to be able to hide how many records you have, for business
purposes, but also to make IDs non-predictable.

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

You need to also add a column, called `rid` of type string/varchar. It is recommended that you also add an index on that
column.

The method to_param will be overridden to return the rid instead of the id.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am "Add some feature"`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
