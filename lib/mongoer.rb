class Mongoer
  class << self
    # sample input AST
    # ---- 'name3 desc:desk2' -------
    # [{:type=>:str, :value=>"name3"},
    #  {:type=>:nest,
    #   :nest_type=>:colon,
    #   :nest_op=>":",
    #   :value=>[{:type=>:str, :value=>"desc"}, {:type=>:str, :value=>"desk2"}]}]

    #     search('name3 desc:desk2') =>
    #      {'$and' => [
    #         { '$or' => [
    #           { 'title' => /name3/mi },
    #           { 'description' => /name3/mi },
    #           { 'tags' => /name3/mi }]},
    #         { 'description' => /desk2/mi }]}

    def build_search(str, fields)
      fields = [fields] unless fields.is_a?(Array)
      forms = fields.map { |f| { f => /#{str}/mi } }
      return forms if forms.count < 2
      { '$or' => forms }
    end

    def build_command(ast_node, command_types)
      # aliasing will be probably done before ast gets to mongoer.rb
      (field_node, search_node) = ast_node[:value]
      key = field_node[:value]
      raw_val = search_node[:value]
      type = command_types[key.to_sym] # String, Numeric, TODO: boolean, time
      if type == String
        val = /#{raw_val}/mi
      elsif type == Numeric
        if raw_val == raw_val.to_i.to_s
          val = raw_val.to_i
        else
          val = raw_val.to_f
        end
      end

      # regex (case insensitive probably best default, and let
      # proper regex and alias support allow developers to have
      # case sensitive if they want maybe.)

      { key => val }
    end

    def build_compare(ast_node, _command_types)
      # this should maybe error if not numeric and all
      (field_node, search_node) = ast_node[:value]
      key = field_node[:value]
      raw_val = search_node[:value]
      if raw_val == raw_val.to_i.to_s
        val = raw_val.to_i
      else
        val = raw_val.to_f
      end
      op_map = {
        '<' => '$lt',
        '>' => '$gt',
        '<=' => '$lte',
        '>=' => '$gte'
      }
      op = op_map[ast_node[:nest_op]]
      { key => { op => val } }
    end

    def build_searches(ast, fields, command_types)
      ast.flat_map do |x|
        case x[:nest_type]
        when nil
          x = build_search(x[:value], fields)
        when :colon
          x = build_command(x, command_types)
        when :compare
          x = build_compare(x, command_types)
          x
        else
          # [:paren, :pipe, :minus]
          x[:value] = build_searches(x[:value], fields, command_types)
          x
        end
      end
    end

    def build_tree(ast)
      ast.flat_map do |x|
        next x unless x[:nest_type]
        mongo_types = { paren: '$and', pipe: '$or', minus: '$not' }
        key = mongo_types[x[:nest_type]]
        { key => build_tree(x[:value]) }
      end
    end

    def collapse_ors(ast)
      ast.flat_map do |x|
        ['$and', '$or', '$not'].map do |key|
          next unless x[key]
          x[key] = collapse_ors(x[key])
        end
        next x unless x['$or']
        val = x['$or'].flat_map { |kid| kid['$or'] || kid }
        { '$or' => val }
      end
    end

    def build_query(ast, fields, command_types = {})
      # Numbers are searched as strings unless part of a compare/command
      out = ast
      out = build_searches(out, fields, command_types)
      out = build_tree(out)
      out = collapse_ors(out)
      out = out.first if out.count == 1
      out = { '$and' => out } if out.count > 1
      out
    end
  end
end
