# '()' => ''
# '-()' => ''
# '(a)' => a
# 'a (b c)' => 'a b c'
# '-(a)' => '-a'
# '-(-a)' => 'a'
# 'a a' => 'a'
# 'a|a' => 'a'
# 'a|a|b' => 'a|b'

# '-(a a)' => '-a'

# 'a (a (a (a (a))))' => 'a'

# 'a b (a b (a b))' => 'a b'
# 'a|b a|b' => 'a|b'

# TODO:

# 'a|-a' => ''
# 'a b a|b' => 'a b'
# '(a b c) | (a b)' => 'a b'

load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Optimizer do

  def parse(x)
    tokens = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(tokens)
  end

  def opt(x)
    CommandSearch::Optimizer.optimize!(parse(x))
  end

  it 'should work and be a no-op in some cases' do
    opt('foo 1 2 a b').should == CommandSearch::Optimizer.optimize!(opt('foo 1 2 a b'))
    opt('red "blue green"').should == parse('red "blue green"')
    opt('foo 1 2').should == [
      { type: :str, value: 'foo' },
      { type: :number, value: '1' },
      { type: :number, value: '2' }
    ]
    str_list = [
      'foo',
      '-foo',
      '-foo:bar',
      'hello<=44.2',
      '-5.2',
      '- -12',
      'ab-dc',
      'a a|b',
      'a<=a',
      'red>red',
      'red>=blue',
      'red "blue green"',
      '1 2 2.34 3 -100 -4.30',
      '(a b) | (c d)'
    ]
    str_list.each do |str|
      opt(str).should == parse(str)
    end
  end

  it 'should denest parens' do
    opt('a').should == [{ type: :str, value: 'a' }]
    opt('(a)').should == [{ type: :str, value: 'a' }]
    opt('a a').should == [{ type: :str, value: 'a' }]
    opt('a a a a a a').should == [{ type: :str, value: 'a' }]
    opt('(a a a a a a)').should == [{ type: :str, value: 'a' }]
    opt('(a a (a (a)) () (a a))').should == [{ type: :str, value: 'a' }]
    opt('(a a a a a "a")').should_not == [{ type: :str, value: 'a' }]
    opt('(a a)').should == [{ type: :str, value: 'a' }]
    opt('(1 foo 2)').should == [
      { type: :number, value: '1' },
      { type: :str, value: 'foo' },
      { type: :number, value: '2' }
    ]
    opt('a (x (foo bar) y) b').should == [
      { type: :str, value: 'a' },
      { type: :str, value: 'x' },
      { type: :str, value: 'foo' },
      { type: :str, value: 'bar' },
      { type: :str, value: 'y' },
      { type: :str, value: 'b' }
    ]
    opt('1 (2 (3 (4 4.5 (5))) 6) 7').should == [
      { type: :number, value: '1' },
      { type: :number, value: '2' },
      { type: :number, value: '3' },
      { type: :number, value: '4' },
      { type: :number, value: '4.5' },
      { type: :number, value: '5' },
      { type: :number, value: '6' },
      { type: :number, value: '7' }
    ]
  end

  it 'should handle OR statements' do
    opt('a|b').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      }
    ]
    opt('(a|b c)|z').should == [
      {
        type: :or,
        value: [
          {
            type: :and,
            value: [
              {
                type: :or,
                value: [
                  { type: :str, value: 'a' },
                  { type: :str, value: 'b' }
                ]
              },
              { type: :str, value: 'c' }
            ]
          },
          { type: :str, value: 'z' }
        ]
      }
    ]
    opt('a|1 2|b').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :number, value: '1' }
        ]
      },
      {
        type: :or,
        value: [
          { type: :number, value: '2' },
          { type: :str, value: 'b' }
        ]
      }
    ]
    opt('a|b|3').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' },
          { type: :number, value: '3' }
        ]
      }
    ]
    opt('(a) | (a|b)').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' }
        ]
      }
    ]
    opt('a|(b|3)').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' },
          { type: :number, value: '3' }
        ]
      }
    ]
    opt('a|(b|(3|4))').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' },
          { type: :number, value: '3' },
          { type: :number, value: '4' }
        ]
      }
    ]
    opt('(a|b|((c|d)|(e|f)))').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' },
          { type: :str, value: 'c' },
          { type: :str, value: 'd' },
          { type: :str, value: 'e' },
          { type: :str, value: 'f' }
        ]
      }
    ]
    opt('(a|b|((c|d)|(e|f|g)))').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' },
          { type: :str, value: 'c' },
          { type: :str, value: 'd' },
          { type: :str, value: 'e' },
          { type: :str, value: 'f' },
          { type: :str, value: 'g' }
        ]
      }
    ]
    opt('(a|b|((c|d)|(e|f|g)|h|i)|j)|k|l|a').should == [
      {
        type: :or,
        value: [
          { type: :str, value: 'a' },
          { type: :str, value: 'b' },
          { type: :str, value: 'c' },
          { type: :str, value: 'd' },
          { type: :str, value: 'e' },
          { type: :str, value: 'f' },
          { type: :str, value: 'g' },
          { type: :str, value: 'h' },
          { type: :str, value: 'i' },
          { type: :str, value: 'j' },
          { type: :str, value: 'k' },
          { type: :str, value: 'l' }
        ]
      }
    ]
    opt('(a b) | (c d)').should == [
      {
        type: :or,
        value: [
          {
            type: :and,
            value: [
              { type: :str, value: 'a' },
              { type: :str, value: 'b' }
            ]
          },
          {
            type: :and,
            value: [
              { type: :str, value: 'c' },
              { type: :str, value: 'd' }
            ]
          }
        ]
      }
    ]
    opt('(a b) | (c d) | (x y)').should == [
      {
        type: :or,
        value: [
          {
            type: :and,
            value: [
              { type: :str, value: 'a' },
              { type: :str, value: 'b' }
            ]
          },
          {
            type: :and,
            value: [
              { type: :str, value: 'c' },
              { type: :str, value: 'd' }
            ]
          },
          {
            type: :and,
            value: [
              { type: :str, value: 'x' },
              { type: :str, value: 'y' }
            ]
          }
        ]
      }
    ]
  end

  it 'should handle for empty nonsense' do
    opt('').should == []
    opt('   ').should == []
    opt("   \n ").should == []
    opt('()').should == []
    opt('-()').should == []
    opt('-(-)').should == []
    opt('-|').should == []
    opt(' ( ( ()) -(()  )) ').should == []
    opt(' ( ( ()) -((-(()||(()|()))|(()|())-((-())))  )) ').should == []
    opt('-""').should == [{ type: :not, value: [{ type: :quote, value: '' }] }]
  end

  it 'should handle wacky nonsense' do
    opt('|').should == []
    opt('(-)').should == []
    opt('(|)').should == []
    opt('(()').should == []
    opt('(())').should == []
    opt(')())').should == []
    opt('-').should == []
    opt(':').should == [{ type: :str, value: ':' }]
    opt('(:)').should == [{ type: :str, value: ':' }]
    opt('>').should == [{ type: :str, value: '>' }]
    opt('>>').should == [{ type: :str, value: '>>' }]
    opt('>:').should == [{ type: :str, value: '>:' }]
    opt('>=').should == [{ type: :str, value: '>=' }]
    opt('>=>').should == [{ type: :str, value: '>=>' }]
    opt('<').should == [{ type: :str, value: '<' }]
    opt('<=').should == [{ type: :str, value: '<=' }]
    opt('-<').should == [
      {
        type: :not,
        value: [{ type: :str, value: '<' }]
      }
    ]
    opt('-<=').should == [
      {
        type: :not,
        value: [{ type: :str, value: '<=' }]
      }
    ]
    opt('|:)').should == [{ type: :str, value: ':' }]
    opt('-<>=-()<>:|(>=-|:)').should == [
      {
        type: :not,
        value: [
          {
            type: :compare,
            nest_op: '>=',
            value: [
              { type: :str, value: '<' },
              { type: :str, value: '-' }
            ]
          }
        ]
      },
      {
        type: :or,
        value: [
          { type: :str, value: '<>:' },
          { type: :str, value: '>=-' },
          { type: :str, value: ':' }
        ]
      }
    ]
  end

  it 'should handle empty strings' do
    opt('""').should == [{ type: :quote, value: '' }]
    opt('""|""').should == [{ type: :quote, value: '' }]
    opt('(""|"")').should == [{ type: :quote, value: '' }]
    opt('(""|"")|""|("")|(""|(""|((""|"")|(""|""))))').should == [{ type: :quote, value: '' }]
    opt("''").should == [{ type: :quote, value: '' }]
    opt("'' foo").should == [{ type: :quote, value: '' }, { type: :str, value: 'foo' }]
    opt('foo:""').should == [{
      type: :colon,
      nest_op: ':',
      value: [
        { type: :str, value: 'foo' },
        { type: :quote, value: '' }
      ]
    }]
  end

  it 'should handle single sides ORs' do
    opt('|a').should == [{ type: :str, value: 'a' }]
    opt('a|').should == [{ type: :str, value: 'a' }]
    opt('||||a').should == [{ type: :str, value: 'a' }]
    opt('a||').should == [{ type: :str, value: 'a' }]
    opt('|a|').should == [{ type: :str, value: 'a' }]
    opt('||a|||').should == [{ type: :str, value: 'a' }]
    opt('||a|()||').should == [{ type: :str, value: 'a' }]
  end

  it 'should handle negating' do
    opt('- -a').should == [{ type: :str, value: 'a' }]
    opt('-a').should == [
      {
        type: :not,
        value: [{ type: :str, value: 'a' }]
      }
    ]
    opt('- -1').should == [
      {
        type: :not,
        value: [{ type: :number, value: '-1' }]
      }
    ]
    opt('-(-1 2 -foo)').should == [
      {
        type: :not,
        value: [
          { type: :number, value: '-1' },
          { type: :number, value: '2' },
          { type: :not, value: [{ type: :str, value: 'foo' }] }
        ]
      }
    ]
    opt('-(-a b)').should == [{
      type: :not,
      value: [
        {
          type: :not,
          value: [{ type: :str, value: 'a' }]
        },
        { type: :str, value: 'b' }
      ]
    }]
    opt('-(a -b)').should == [{
      type: :not,
      value: [
        { type: :str, value: 'a' },
        {
          type: :not,
          value: [
            { type: :str, value: 'b' }
          ]
        }
      ]
    }]
    opt('-(-a -b)').should == [{
      type: :not,
      value: [
        {
          type: :not,
          value: [{ type: :str, value: 'a' }]
        },
        {
          type: :not,
          value: [
            { type: :str, value: 'b' }
          ]
        }
      ]
    }]
    opt('-(foo|-bar)|3').should == [{
      type: :or,
      value: [
        {
          type: :not,
          value: [{
            type: :or,
            value: [
              { type: :str, value: 'foo' },
              {
                type: :not,
                value: [{ type: :str, value: 'bar' }]
              }
            ]
          }]
        },
        { type: :number, value: '3' }
      ]
    }]

  end

  # it 'should handle fancier logic' do
  #   opt('-a a').should == []
  #   opt('a b a|b').should == [{type: :str, value: 'a'},
  #                             {type: :str, value: 'b'}]
  #   opt('(a b c) | (a b)').should == [{type: :str, value: 'a'},
  #                                     {type: :str, value: 'b'}]
  # end
end
