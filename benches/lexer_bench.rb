require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips do |bm|
  $bm = bm

  def lex(input)
    title = "Lex #{input.length}: #{input.inspect}"
    title = title[0..18] + '…' if title.length > 18
    $bm.report(title) { CommandSearch::Lexer.lex(input) }
  end

  lex('')
  lex('foo')
  lex('foo bar')
  lex('name title:name')
  lex('abcedefhijklmnopqrstuvwxyz')
  lex('AbCeDeFhIjKlMnOpQrStUvWxYz')
  lex('abcedefhijklmnopqrstuvwxyz0123456789')
  lex('0123456789')
  lex('a b c e d e f h i j k l 3 4 5 6 7 8 9')
  lex('foo:bar apple|bannana cost<=100')
  lex('foo:bar apple|bannana cost<=100' * 100)
  lex('ab12' * 12)
  lex('"fo" \'ba\'' * 12)
end
