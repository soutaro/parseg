tokenizer = Parseg::StrscanTokenizer.new(
  {
      tPLUS: /\+/,
      tMINUS: /\-/,
      tSTAR: /\*/,
      tSLASH: /\//,
      tLPAREN: /\(/,
      tRPAREN: /\)/,
      tINTEGER: /\d+/
  },
  /\s+/   # Skips spaces
)

grammar = Parseg::Grammar.new do |grammar|
  grammar[:start].rule = NT(:expr)

  # expr ::= factor (`+` | `-`) ... (`+` | `-`) factor
  grammar[:expr].rule = Repeat(NT(:factor), Alt(T(:tPLUS), T(:tMINUS)))

  # factor ::= term (`*` | `/`) ... (`*` | `/`) term
  grammar[:factor].rule = Repeat(NT(:term), Alt(T(:tSTAR), T(:tSLASH)))

  # term ::= `(` expr `)`
  #        | tINTEGER
  grammar[:term].rule = Alt(
    T(:tLPAREN) + NT(:expr) + T(:tRPAREN),
    T(:tINTEGER)
  )
end

[tokenizer, grammar]
