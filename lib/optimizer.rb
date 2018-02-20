class Optimizer
  class << self
    # '()' => ''
    # '-()' => ''
    # '(a)' => a
    # 'a (b c)' => 'a b c'
    # '-(a)' => '-a'
    # '-(-a)' => 'a'
    # 'a a' => 'a'
    # 'a|a' => 'a'
    # 'a|a|b' => 'a|b'
    # 'a|b b|c' => 'a|b|c'

    # maybe...
    # '(a b) | (a c)' => 'a b|c'

    # parse('a (x (foo bar) y) b').should == [
    #   {type: :str, value: "a"},
    #   {type: :nest,
    #    nest_type: :paren,
    #    value: [
    #      {type: :str, value: "x"},
    #      {type: :nest,
    #       nest_type: :paren,
    #       value: [
    #         {type: :str, value: "foo"},
    #         {type: :str, value: "bar"}]},
    #      {type: :str, value: "y"}]},
    #   {type: :str, value: "b"}]

    def negate_negate(ast)
      ast.flat_map do |node|
        next node unless node[:nest_type]
        node[:value] = negate_negate(node[:value])
        next [] if node[:value] == []
        next node if node[:value].count > 1
        type = node[:nest_type]
        child_type = node[:value].first[:nest_type]
        next node unless type == :minus && child_type == :minus
        node[:value].first[:value]
      end
    end

    def denest_parens(ast, parent_type = :root)
      ast.flat_map do |node|
        next node unless node[:nest_type]
        node[:value] = denest_parens(node[:value], node[:nest_type])
        next [] if node[:value] == []
        next node unless node[:nest_type] == :paren
        valid_op = parent_type == :pipe || parent_type == :minus
        next node[:value] unless valid_op
        next node[:value] if node[:value].count < 2
        node
      end
    end

    def optimize(ast)
      out = ast
      out = denest_parens(out)
      out = negate_negate(out)
      out
    end
  end
end

# load('~/projects/searchable/lib/lexer.rb')
# load('~/projects/searchable/lib/parser.rb')
# require('pp')

# str = 'a -(b (c))'

# a = Lexer.lex(str)
# b = Parser.parse(a)
# c = Optimizer.optimize(b)

# pp c


# str = '-()'

# a = Lexer.lex(str)
# b = Parser.parse(a)
# c = Optimizer.optimize(b)

# pp c


# str = '-(-a)'

# a = Lexer.lex(str)
# b = Parser.parse(a)
# c = Optimizer.optimize(b)

# pp c
