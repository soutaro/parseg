require "parseg"
require "strscan"

parser_definition = ARGV.shift

unless parser_definition
  puts "runner.rb PARSER START [SOURCE...]"
  return
end

tokenizer, grammar = eval(File.read(parser_definition), binding, parser_definition)

formatter = Parseg::TreeFormatter.new()

unless start = ARGV.shift
  puts "runner.rb PARSER START [SOURCE...]"
  puts "  where `START` is one of { #{grammar.non_terminals.keys.join(", ")} }"
  return
end

ARGV.each do |file|
  content = File.read(file)

  result = Parseg::Parser.new(
    grammar: grammar,
    tokenizer: tokenizer[content]
  ).parse(grammar[start.to_sym])

  pp formatter.format(result)
end
