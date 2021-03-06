require('benchmark/ips')

load(__dir__ + '/../lib/command_search.rb')

Benchmark.ips() do |bm|
  $bm = bm

  def bench(input)
    title = "Optimize #{input.length}: #{input.inspect[0..24]}"
    ast = CommandSearch::Lexer.lex(input)
    CommandSearch::Parser.parse!(ast)
    $bm.report(title) { CommandSearch::Optimizer.optimize!(ast) }
  end

  bench('')
  bench('a|b|(a|b|c)|')
  bench('a|a a|b|(a|b|c)|')
  bench('a (b c) a|a a|b|(a|b|c)|')
  bench('(((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|')
  bench('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|')
  bench('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 100)
  bench('a lemon a -() a b (a b (a b)) -((-())) (((a))) (a (a ((a)))) a (b c) a|a a|b|(a|b|c)|' * 1000)
end
