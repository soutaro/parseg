module Parseg
  class StrscanTokenizer
    attr_reader :tokens, :skips

    def initialize(tokens, skips)
      @tokens = tokens
      @skips = skips
    end

    __skip__ = def tokenizer(string)
      tokenizer = Object.new

      scan = StringScanner.new(string)

      skips = skips()
      tokens = tokens()

      tokenizer.singleton_class.define_method(:next_token) do
        while str = scan.scan(skips)
          # nop
        end

        tokens.each do |type, regexp|
          if str = scan.scan(regexp)
            return [type, scan.charpos - str.size, str]
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
    end
  end
end
