module Parseg
  class StrscanTokenizer
    attr_reader :tokens, :skips

    def initialize(tokens, skips)
      @tokens = tokens
      @skips = skips
    end

    def each_token(string)
      scan = StringScanner.new(string)

      while true
        while scan.scan(skips)
          # nop
        end

        break if scan.eos?

        tokens.each do |type, regexp|
          # @type break: nil
          if str = scan.scan(regexp)
            yield [type, scan.charpos - str.size, str]
            break
          end
        end
      end

      yield nil
    end
  end
end
