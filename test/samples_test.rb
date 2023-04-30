require "test_helper"

def empty_binding
  binding
end

class SamplesTest < Minitest::Test
  include TreeAssertion

  def test_samples
    dir = Pathname(__dir__) + "../samples"

    dir.glob("*.rb").each do |grammar_file|
      tokenizer, grammar = eval(grammar_file.read, empty_binding, grammar.to_s)

      grammar_dir = grammar_file.sub_ext("")

      if grammar_dir.directory?
        grammar_dir.each_child do |sample_path|
          factory = Parseg::TokenFactory.new(tokenizer: tokenizer, status: sample_path.read)
          parser = Parseg::Parser.new(grammar: grammar, factory: factory)

          parser.error_tolerant_enabled = false
          parser.skip_unknown_tokens_enabled = false

          result = parser.parse(grammar.non_terminals[:start])

          refute result.has_error?, "Parsing #{sample_path} by #{grammar_file} failed"
        end
      end
    end
  end
end
