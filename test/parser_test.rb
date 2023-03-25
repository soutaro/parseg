require "test_helper"

class ParserTest < Minitest::Test
  include TreeAssertion

  Tokenizer = Parseg::StrscanTokenizer.new(
    {
      INTEGER: /\d+/,
      PLUS: /\+/,
      MINUS: /\-/,
      MUL: /\*/,
      LPAREN: /\(/,
      RPAREN: /\)/,
      IDENT: /[a-z]\w*/
    },
    /(\s+)|(#[^\n]*)/
  )

  Grammar = Parseg::Grammar.new do |grammar|
    grammar[:term].rule =
      Alt(
        T(:INTEGER),
        T(:LPAREN) + NT(:expr) + T(:RPAREN)
      )

    grammar[:variable].rule = T(:IDENT)

    grammar[:term1].rule = Repeat(NT(:term), T(:MUL))

    grammar[:expr].rule = Repeat(NT(:term1), Alt(T(:PLUS), T(:MINUS)))

    grammar[:exprs].rule = Repeat(NT(:expr))
  end

  def parse(string, start = :exprs)
    parser = Parseg::Parser.new(
      grammar: Grammar,
      tokenizer: Tokenizer.tokenizer(string)
    )

    yield parser if block_given?

    parser.parse(Grammar.non_terminals[start])
  end

  def test_parse_success1
    result = parse("123 (456)")

    assert_tree(
      result.tree,
      {
        exprs: [
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "123"]
                    ]
                  }
                ]
              }
            ]
          },
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:LPAREN, "("],
                      {
                        expr: [
                          {
                            term1: [
                              {
                                term: [
                                  [:INTEGER, "456"]
                                ]
                              }
                            ]
                          }
                        ]
                      },
                      [:RPAREN, ")"]
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      locator: result.token_locator
    )
  end

  def test_parse_success2
    result = parse("1 + 2 * 3 - 4")

    assert_tree(
      result.tree,
      {
        exprs: [
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "1"]
                    ]
                  }
                ]
              },
              [:PLUS, "+"],
              {
                term1: [
                  { term: [ [:INTEGER, "2"] ]},
                  [:MUL, "*"],
                  { term: [ [:INTEGER, "3"] ]}
                ]
              },
              [:MINUS, "-"],
              {
                term1: [
                  { term: [ [:INTEGER, "4"] ]}
                ]
              }
            ]
          },
        ]
      },
      locator: result.token_locator
    )
  end

  def test_parse_error_no_recovery
    result = parse("(") {|p| p.error_tolerant_enabled = false }

    assert_tree(
      result.tree,
      {
        unexpected: nil
      },
      locator: result.token_locator
    )
  end

  def test_missing_1
    result = parse("(123 +)", :term)

    assert_tree(
      result.tree,
      {
        term: [
          [:LPAREN, "("],
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "123"]
                    ]
                  }
                ]
              },
              [:PLUS, "+"],
              { unexpected: :RPAREN }
            ]
          },
          [:RPAREN, ")"]
        ]
      },
      locator: result.token_locator
    )
  end

  def test_missing_2
    result = parse("123 + +", :exprs)

    assert_tree(
      result.tree,
      {
        exprs: [
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "123"]
                    ]
                  }
                ]
              },
              [:PLUS, "+"],
              { unexpected: :PLUS },
              [:PLUS, "+"],
              { unexpected: nil }
            ]
          }
        ]
      },
      locator: result.token_locator
    )
  end

  def test_missing_3
    result = parse("1+2 3", :exprs)

    assert_tree(
      result.tree,
      {
        exprs: [
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "1"]
                    ]
                  }
                ]
              },
              [:PLUS, "+"],
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "2"]
                    ]
                  }
                ]
              }
            ],
          },
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:INTEGER, "3"]
                    ]
                  }
                ]
              },
            ]
          }
        ]
      },
      locator: result.token_locator
    )
  end

  def test_missing_4
    result = parse("(1 a)", :exprs)

    assert_tree(
      result.tree,
      {
        exprs: [
          {
            expr: [
              {
                term1: [
                  {
                    term: [
                      [:LPAREN, "("],
                      {
                        expr: [
                          {
                            term1: [
                              {
                                term: [
                                  [:INTEGER, "1"]
                                ]
                              }
                            ]
                          }
                        ]
                      },
                      {
                        unexpected: :IDENT
                      }
                    ]
                  },
                ]
              }
            ]
          },
          { unexpected: :IDENT }
        ]
      },
      locator: result.token_locator
    )
  end
end
