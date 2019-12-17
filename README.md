# Command Search
[![CircleCI](https://circleci.com/gh/zumbalogy/command_search.svg?style=svg)](https://circleci.com/gh/zumbalogy/command_search)

A Ruby gem to help let users query collections.

command_search should make it easy to create search inputs where
users can search for `flamingos` or `author:herbert`, as well
as using negations, comparisons, ors, and ands.

command_search also supports aliasing so that the following substitutions are easy to make:
* `name:alice` to `user_name:alice`
* `A+` to `grade>=97`
* `user:me` to `user:59guwJphUhqfd2A` (but with the actual ID)
* `hair=blue` to `hair:blue`

command_search does not require an engine and should be easy to set up.

command_search works with
[PostgreSQL](https://www.postgresql.org/),
[SQLite](https://www.sqlite.org/),
[MongoDB](https://www.mongodb.com/),
and in-memory arrays of Ruby hashes.

command_search is written with performance in mind and should have minimal overhead for most queries.

A sample Rails app using command_search can be seen at [github.com/zumbalogy/command_search_example](https://github.com/zumbalogy/command_search_example).

A live version can be found at [earthquake-search.herokuapp.com](https://earthquake-search.herokuapp.com/).

Feedback, questions, bug reports, pull requests, and suggestions are welcome.

## Install
Command Line:
```ruby
gem install command_search
```
Gemfile:
```ruby
gem 'command_search'
```

## Syntax
Normal queries like `friday dinner`, `shoelace`, or `treehouse` work normally,
and will perform case-insensitive partial matching per space-delineated part of
the query. The order of the parts should not affect the search results. A user
can specify full-word and case-sensitive query parts by using quotation marks,
so the search `'ann'` will not match "anne" or `"bob"` to not match "bobby".
Quoted query parts can search for whole phrases, such as `"You had me at
HELLO!"`. Collections can also be queried with commands, which can be used in
combination.

| Command | Character            | Examples                               |
| ----    | -----                | ----------                             |
| Specify | `:`                  | `attachment:true`, `grade:A`           |
| And     | `(...)`              | `(error important)`, `liked poked` (Note: space is an implicit and) |
| Or      | `\|`                 | `color\|colour`, `red\|orange\|yellow` |
| Compare | `<`, `>`, `<=`, `>=` | `created_at<monday`, `100<=pokes`      |
| Negate  | `-`                  | `-error`, `-(sat\|sun)`                |

## Limitations
The logic can be slow (100ms+) for queries that exceed 10,000 characters.
In public APIs or performance sensitive use cases, long inputs should
be truncated or otherwise accounted for.

Date/Time searches are only parsed into dates for command searches that
specify (`:`) or compare (`<`, `>`, `<=`, `>=`).

'Fuzzy' searching is not currently supported.

## Dependencies
[Chronic](https://github.com/mojombo/chronic) is currently used to parse user
submitted dates, such as `tuesday` or `1/1/11`. Chronic's handling of timezones
and leap years and such is not perfect, but is only used if 'Date' is declared
as a field type in the config.

## Setup
To query collections, command_search provides the CommandSearch.search function,
which takes a collection, a query, and an options hash.

* Collection: Either an array of hashes or a class that is a Mongoid::Document.

* Query: The string to use to search the collection, such as 'user:me' or 'bee|wasp'.

* Options: A hash that describes how to search the collection.

  * fields: A hash that maps symbols matching a field's name
  to its type, another symbol as an alias, or a hash. Valid types are `String`,
  `Boolean`, `Numeric`, and `Time`.
  Fields to be searched though when no field is specified in the query should be
  marked like so: `description: { type: String, general_search: true }`
  `Boolean` fields will check for existence of a value if the underlying
  data is not actually a boolean, so the query `bookmarked:true` could work even
  if the bookmarked field is a timestamp. To be able to query the bookmarked
  field as both a timestamp and a boolean, a symbol can be added to the value
  in the hash like so: `bookmarked: { type: Time, allow_existence_boolean: true }`.

  * aliases: A hash that maps strings or regex to strings or procs.
  CommandSearch will iterate though the hash and substitute parts of the query
  that match the key with the value or the returned value of the proc. The procs
  will be called once per match with the value of the match and are free to have
  closures and side effects.
  This happens before any other parsing or searching steps.
  Keys that are strings will be converted into a regex that is case insensitive,
  respects word boundaries, and does not alias quoted sections of the query. Note
  that, for aliasing purposes, specifying and comparing query parts are treated as
  whole words, so `'foo' => 'bar'` will not effect the query `baz:foo`.
  Regex keys will be used as is, but respect user quotations unless the regex
  matches the quotes. A query can be altered before being passed to CommandSearch
  to sidestep any limitation. NOTE: If aliasing to something complex, wrapping the
  output in parentheses can help it work as expected with the command_search syntax.

## Examples

An example setup for searching a Foo class in MongoDB:
```ruby
class Foo
  include Mongoid::Document
  field :title,       type: String
  field :description, type: String
  field :tags,        type: String
  field :child_id,    type: String
  field :feathers,    type: Integer
  field :cost,        type: Integer
  field :starred,     type: Boolean
  field :fav_date,    type: Time

  def self.search(query)
    options = {
      fields: {
        child_id: Boolean,
        title: { type: String, general_search: true },
        name: :title,
        description: { type: String, general_search: true },
        desc: :description,
        starred: Boolean,
        star: :starred,
        tags: { type: String, general_search: true },
        tag: :tags,
        feathers: [Numeric, :allow_existence_boolean],
        cost: Numeric,
        fav_date: Time
      },
      aliases: {
        'favorite' => 'starred:true',
        'classic' => '(starred:true fav_date<15_years_ago)'
        /=/ => ':',
        'me' => -> () { current_user.name },
        /\$\d+/ => -> (match) { "cost:#{match[1..-1]}" }
      }
    }
    CommandSearch.search(Foo, query, options)
  end
end
```

An example setup of using aliases to allow users to choose how a list is sorted:
```ruby
class SortableFoo
  include Mongoid::Document
  field :foo, type: String
  field :bar, type: String

  def self.search(query)
    head_border = '(?<=^|\s|[|(-])'
    tail_border = '(?=$|\s|[|)])'
    sortable_field_names = ['foo', 'bar']
    sort_field = nil
    options = {
      fields: {
        foo: { type: String, general_search: true },
        bar: { type: String }
      },
      aliases: {
        /#{head_border}sort:\S+#{tail_border}/ => proc { |match|
          match_sort = match.sub(/^sort:/, '')
          sort_field = match_sort if sortable_field_names.include?(match_sort)
          ''
        }
      }
    }
    results = CommandSearch.search(SortableFoo, query, options)
    results = results.order_by(sort_field => :asc) if sort_field
    return results
  end
end
