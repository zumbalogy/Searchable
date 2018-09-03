load(__dir__ + '/lexer.rb')
load(__dir__ + '/parser.rb')
load(__dir__ + '/dealiaser.rb')
load(__dir__ + '/optimizer.rb')
load(__dir__ + '/mongoer.rb')
load(__dir__ + '/memory.rb')

class Boolean; end

class Searchable
  class << self

    def search(source, query, fields, command_fields = {})
      tokens = Lexer.lex(query)
      parsed = Parser.parse(tokens)
      dealiased = Dealiaser.dealias(parsed, command_fields)
      opted = Optimizer.optimize(dealiased)
      if source.respond_to?(:mongo_client) && source.queryable
        fields = [:__SEARCHABLE_mongo_search_field_dummy_key__] if fields.empty?
        mongo_query = Mongoer.build_query(opted, fields, command_fields)
        return source.where(mongo_query)
      end
      selector = Memory.build_query(opted, fields, command_fields)
      source.select(&selector)
    end

  end
end
