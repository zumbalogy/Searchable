require('chronic')

module CommandSearch
  module Normalizer
    module_function

    def cast_bool!(field, node)
      type = field.is_a?(Hash) ? field[:type] : field
      if type == Boolean
        node[:type] = Boolean
        node[:value] = !!node[:value][0][/t/i]
        return
      end
      return unless field.is_a?(Hash) && field[:allow_existence_boolean]
      return unless node[:type] == :str && node[:value][/\Atrue\Z|\Afalse\Z/i]
      node[:type] = :existence
      node[:value] = !!node[:value][0][/t/i]
    end

    def cast_time!(node)
      search_node = node[:value][1]
      search_node[:type] = Time
      str = search_node[:value]
      if str == str.to_i.to_s
        search_node[:value] = [Time.new(str), Time.new(str.to_i + 1)]
      else
        time_str = str.tr('._-', ' ')
        times = Chronic.parse(time_str, { guess: nil })
        times ||= Chronic.parse(str, { guess: nil })
        if times
          search_node[:value] = [times.first, times.last]
        else
          search_node[:value] = nil
          return
        end
      end
      return unless node[:nest_type] == :compare
      op = node[:nest_op]
      if op == '<' || op == '>='
        search_node[:value] = search_node[:value].first
      else
        search_node[:value] = search_node[:value].last
        search_node[:value] -= 1
      end
    end

    def cast_regex!(node)
      type = node[:type]
      raw = node[:value]
      return unless raw.is_a?(String)
      return if node[:value] == ''
      str = Regexp.escape(raw)
      return node[:value] = /#{str}/i unless type == :quoted_str
      return node[:value] = /\b#{str}\b/ unless raw[/(^\W)|(\W$)/]
      border_a = '(^|\s|[^:+\w])'
      border_b = '($|\s|[^:+\w])'
      node[:value] = Regexp.new(border_a + str + border_b)
    end

    def cast_numeric!(node)
      return unless node[:type] == :number
      node[:value] = node[:value].to_f
    end

    def clean_comparison!(node, fields)
      val = node[:value]
      return unless fields[val[1][:value].to_sym]
      if fields[val[0][:value].to_sym]
        node[:compare_across_fields] = true
        return
      end
      flip_ops = { '<' => '>', '>' => '<', '<=' => '>=', '>=' => '<=' }
      node[:nest_op] = flip_ops[node[:nest_op]]
      node[:value].reverse!
    end

    def dealias_key(key, fields)
      key = fields[key.to_sym] while fields[key.to_sym].is_a?(Symbol)
      key
    end

    def split_into_fields(node, general_fields)
      new_val = general_fields.map do |field|
        {
          type: :nest,
          nest_type: :colon,
          value: [
            { value: field.to_s },
            { value: node[:value], type: node[:type] },
          ]
        }
      end
      return new_val.first if new_val.count < 2
      { type: :nest, nest_type: :pipe, value: new_val }
    end

    def dealias!(ast, fields)
      ast.map! do |node|
        nest = node[:nest_type]
        next node unless nest
        unless nest == :colon || nest == :compare
          dealias!(node[:value], fields)
          next node
        end
        clean_comparison!(node, fields) if nest == :compare
        (key_node, search_node) = node[:value]
        new_key = dealias_key(key_node[:value], fields)
        node[:value][0][:value] = new_key.to_s
        field = fields[new_key.to_sym] || fields[new_key.to_s]
        if field && (field.is_a?(Class) || field[:type])
          type = field.is_a?(Class) ? field : field[:type]
          cast_bool!(field, search_node)
          cast_time!(node) if [Time, Date, DateTime].include?(type)
          cast_regex!(search_node) if type == String
          cast_numeric!(search_node) if [Integer, Numeric].include?(type)
          next node
        end
        str_values = "#{new_key}#{node[:nest_op]}#{search_node[:value]}"
        node = { type: :str, value: str_values }
        cast_regex!(node)
        general_fields = fields.select { |k, v| v.is_a?(Hash) && v[:general_search] }.keys
        general_fields = [:__CommandSearch_dummy_key__] if general_fields.empty?
        split_into_fields(node, general_fields)
      end
    end

    def expand_general!(ast, fields)
      general_fields = fields.select { |k, v| v.is_a?(Hash) && v[:general_search] }.keys
      general_fields = [:__CommandSearch_dummy_key__] if general_fields.empty?
      ast.map! do |node|
        nest_type = node[:nest_type]
        if nest_type == :minus || nest_type == :paren || nest_type == :pipe
          expand_general!(node[:value], fields)
        end
        next node if nest_type
        split_into_fields(node, general_fields)
      end
    end

    def normalize!(ast, fields)
      expand_general!(ast, fields)
      dealias!(ast, fields)
    end
  end
end
