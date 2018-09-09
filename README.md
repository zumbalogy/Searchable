# Command Search
[![CircleCI](https://circleci.com/gh/zumbalogy/command_search.svg?style=svg)](https://circleci.com/gh/zumbalogy/command_search)

command_search is a Ruby gem to help users easily query collections.

command_search should make it a breeze to make gmail-style search bars, where
users can search for items that match `flamingos` or `author:herbert`, as well
as using negations, comparisons, ors, and ands.

command_search does not require an engine and should be easy to set up.

## Syntax
Normal queries like `friday dinner`, `shoelace`, or `treehouse` work normally,
and will perform case insensitive partial matching per space-delineated part of
the query.
A user can specify full-word and case sensitive query parts by using quotation
marks, so the search `'ann'` will not match "anne" or `"bob"` to not match
"bobby". Quoted searches can match whole phrases, like `"You had me at HELLO!"`.
Collections can also be queried in a few extra ways, which can be used in
combination.

| Command | Character            | Examples                               |
| ----    | -----                | ----------                             |
| Specify | `:`                  | `attachment:true`, `grade:A`           |
| And     | `(...)`              | `(error important)`, `liked poked` (Note: space is an implicit and) |
| Or      | `\|`                 | `color\|colour`, `red\|orange\|yellow` |
| Compare | `<`, `>`, `<=`, `>=` | `created_at<monday`, `100<=pokes`      |
| Negate  | `-`                  | `-error`, `-(sat\|sun)`                |

## Limitations
Date/Time searches are only parsed into dates for command searches that
specify (`:`) or compare (`<`, `>`, `<=`, `>=`).

'Fuzzy' searching is not currently supported.

The only currently supported collections to query are MongoDB [link] collections
and in-memory arrays of hashes.
SQL support hopefully coming soon.

## Dependencies
[Mongoid](https://github.com/mongodb/mongoid) is assumed if using command_search
to search MongoDB.

[Chronic](https://github.com/mojombo/chronic) is currently used to parse user
submitted dates, such as `tuesday` or `1/1/11`. Chronic's handling of timezones
and leap years and such is not perfect, but is only used if 'Date' is declared
as a field type in the config.

## Install
Command Line:
```
gem install command_search
```
Gemfile:
```ruby
gem 'command_search'
```

## Setup


## Examples

## Technical Details
