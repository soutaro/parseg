require "test_helper"
require "strscan"

class TestExpr < Minitest::Test
  def tokenizer(string)
    tokenizer = Object.new

    scan = StringScanner.new(string)

    tokenizer.singleton_class.define_method(:next_token) do
      scan.skip(/\s/)

      case
      when string = scan.scan(/\d+/)
        [
          :tINTEGER,
          scan.charpos,
          string
        ]
      when string = scan.scan(/\+/)
        [
          :tPLUS,
          scan.charpos,
          string
        ]
      when string = scan.scan(/\-/)
        [
          :tMINUS,
          scan.charpos,
          string
        ]
      when string = scan.scan(/\*/)
        [
          :tSTAR,
          scan.charpos,
          string
        ]
      when string = scan.scan(/\//)
        [
          :tSLASH,
          scan.charpos,
          string
        ]
      when string = scan.scan(/[a-z][a-z0-9]*/)
        [
          :tIDENT,
          scan.charpos,
          string
        ]
      when string = scan.scan(/\(/)
        [
          :tLPAREN,
          scan.charpos,
          string
        ]
      when string = scan.scan(/\)/)
        [
          :tRPAREN,
          scan.charpos,
          string
        ]
      end
    end

    tokenizer
  end

  def define_tokenizer(**defn)
    -> (string) {
      tokenizer = Object.new

      scan = StringScanner.new(string)

      tokenizer.singleton_class.define_method(:next_token) do
        scan.skip(/\s/)

        defn.each do |type, regexp|
          if string = scan.scan(regexp)
            return [type, scan.charpos, string]
          end
        end

        return nil
      end

      tokenizer.singleton_class.define_method(:all_tokens) do
        toks = []

        while tok = next_token
          toks << tok
        end

        toks
      end

      tokenizer
    }
  end

  include Parseg

  def zzz_test_hogehoge
    grammar = Grammar.new(:term, :factor, :expr) do |grammar|
      grammar[:term].rule = Grammar::Expression::Alternation.new(
        Grammar::Expression::TokenSymbol.new(:tINTEGER),
        Grammar::Expression::TokenSymbol.new(:tIDENT) +
        Grammar::Expression::Opt.new(
          Grammar::Expression::TokenSymbol.new(:tLPAREN) +
            Grammar::Expression::Repeat.new(
              content: Grammar::Expression::NonTerminalSymbol.new(grammar[:expr]),
              separator: Grammar::Expression::TokenSymbol.new(:tCOMMA),
              leading: false,
              trailing: false
            ) +
            Grammar::Expression::TokenSymbol.new(:tRPAREN)
        ),
        Grammar::Expression::TokenSymbol.new(:tLPAREN) +
          Grammar::Expression::NonTerminalSymbol.new(grammar[:expr]) +
          Grammar::Expression::TokenSymbol.new(:tRPAREN),
      )

      grammar[:factor].rule = Grammar::Expression::Repeat.new(
        content: Grammar::Expression::NonTerminalSymbol.new(grammar[:term]),
        separator: Grammar::Expression::Alternation.new(
          Grammar::Expression::TokenSymbol.new(:tSTAR),
          Grammar::Expression::TokenSymbol.new(:tSLASH)
        ),
        leading: false,
        trailing: false
      )

      grammar[:expr].rule = Grammar::Expression::Repeat.new(
        content: Grammar::Expression::NonTerminalSymbol.new(grammar[:factor]),
        separator: Grammar::Expression::Alternation.new(
          Grammar::Expression::TokenSymbol.new(:tPLUS),
          Grammar::Expression::TokenSymbol.new(:tMINUS)
        ),
        leading: false,
        trailing: false
      )
    end


    pp grammar[:expr].rule.first_tokens

    formatter = Parseg::TreeFormatter.new
    result = Parseg::Parser.new(grammar: grammar, tokenizer: tokenizer("1 - 2 - a * b(1)")).parse(grammar[:expr])

    pp formatter.format(result.tree)
  end

  def test_method_type
    tokenizer = define_tokenizer(
      kLPAREN: /\(/,
      kRPAREN: /\)/,
      kCOLON2: /::/,
      tNAMESPACE: /([A-Z]\w*::)+/,
      kCOLON: /:/,
      kARROW: /\-\>/,
      kVOID: /void/,
      kUNTYPED: /untyped/,
      kNIL: /nil/,
      kSELFQ: /self\?/,
      kSELF: /self/,
      kCLASS: /class/,
      kMODULE: /module/,
      kSINGLETON: /singleton/,
      kBOOL: /bool/,
      kBAR: /\|/,
      kAND: /\&/,
      kLT: /\</,
      kLBRACKET: /\[/,
      kRBRACKET: /\]/,
      kLBRACE: /\{/,
      kRBRACE: /\}/,
      kCOMMA: /,/,
      kQUESTION: /\?/,
      kSTAR2: /\*\*/,
      kSTAR: /\*/,
      tUKEYWORD: /[A-Z]\w*:/,
      tLKEYWORD: /[a-z]\w*:/,
      tULKEYWORD: /_[a-z]\w*:/,
      tUIDENT: /[A-Z]\w*/,
      tLIDENT: /[a-z]\w*/,
      tULIDENT: /_[A-Z]\w*/,
    )

    grammar = Grammar.new(:simple_type, :type, :base_type, :type_name) do |grammar|
      grammar[:simple_type].rule = Alt(
        T(:tLPAREN) + NT(:type) + T(:tRPAREN),
        NT(:base_type),
        NT(:type_name) + Opt(
          T(:kLBRACKET) + Repeat(NT(:type)).with(separator: T(:kCOMMA)) + T(:kRBRACKET)
        ),
        T(:kSINGLETON) + T(:kLPAREN) + NT(:type_name) + T(:kRPAREN),
        T(:kLBRACKET) + Opt(Repeat(NT(:type)).with(separator: T(:kCOMMA)))  + T(:kRBRACKET)
      )

      grammar[:type_name].rule =
        Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tLIDENT), T(:tULIDENT))

      grammar[:base_type].rule = Alt(
        T(:kVOID), T(:kUNTYPED), T(:kNIL), T(:kSELF), T(:kSELF), T(:kBOOL)
      )

      grammar[:optional_type].rule = NT(:simple_type) + Opt(T(:kQUESTION))

      grammar[:intersection_type].rule =
        Repeat(NT(:optional_type)).with(separator: T(:kAMD), trailing: false, leading: false)

      grammar[:union_type].rule =
        Repeat(NT(:intersection_type)).with(separator: T(:kBAR), trailing: false, leading: false)

      grammar[:type].rule = NT(:union_type)

      grammar[:return_type].rule = NT(:optional_type)

      grammar[:method_type].rule = Opt(NT(:type_params)) + NT(:params) + Opt(NT(:block)) + T(:kARROW) + NT(:return_type)

      grammar[:type_params].rule =
        T(:kLBRACKET) + Repeat(NT(:type_param)).with(separator: T(:kCOMMA)) + T(:kRBRACKET)

      grammar[:type_param].rule =
        T(:tUIDENT) + Opt(T(:kLT) + NT(:upper_bound))

      grammar[:upper_bound].rule =
        Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tULIDENT))

      grammar[:block].rule = Opt(T(:kQUESTION)) + T(:kLBRACE) + NT(:params) + Opt(NT(:block_self_binding)) + T(:kARROW) + NT(:return_type) + T(:kRBRACE)

      grammar[:block_self_binding].rule = T(:kLBRACKET) + T(:kSELF) + T(:kCOLON) + NT(:type) + T(:kRBRACKET)

      grammar[:params].rule = T(:kLPAREN) + Opt(NT(:required_params)) + T(:kRPAREN)

      grammar[:required_params].rule = Alt(
        NT(:required_param) + Opt(T(:kCOMMA) + NT(:required_params)),
        NT(:question_param) + Opt(T(:kCOMMA) + NT(:question_params)),
        NT(:rest_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
        NT(:keyword_params)
      )

      grammar[:question_params].rule = Alt(
        T(:kQUESTION) + Alt(
          NT(:required_param) + Opt(T(:kCOMMA) + NT(:question_params)),
          NT(:keyword_param) + Opt(T(:kCOMMA) + NT(:keyword_params))
        ),
        NT(:rest_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
        NT(:keyword_params)
      )

      grammar[:keyword_params].rule = Alt(
        NT(:keyword_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
        T(:kQUESTION) + NT(:keyword_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
        NT(:keyword_rest_param)
      )

      grammar[:required_param].rule = NT(:type) + Opt(T(:tLIDENT))

      grammar[:question_param].rule = T(:kQUESTION) + Alt(NT(:required_param), NT(:keyword_param))

      grammar[:keyword_param].rule = Alt(T(:tLKEYWORD), T(:tUKEYWORD), T(:tULKEYWORD)) + NT(:type) + Opt(T(:tLIDENT))

      grammar[:rest_param].rule = T(:kSTAR) + NT(:type) + Opt(T(:tLIDENT))

      grammar[:keyword_rest_param].rule = T(:kSTAR2) + NT(:type) + Opt(T(:tLIDENT))
    end

    formatter = Parseg::TreeFormatter.new()

    # pp formatter.format(
    #   Parser.new(grammar: grammar, tokenizer: tokenizer["(Integer, ?String, *bool, foo: Integer, ?name: String, **untyped) -> String"]).parse(grammar[:method_type])
    # )

    pp formatter.format(
      Parser.new(grammar: grammar, tokenizer: tokenizer["[A < String] (A) { () [self: String] -> void } -> String"]).parse(grammar[:method_type])
    )
  end
end

