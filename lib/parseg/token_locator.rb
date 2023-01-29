module Parseg
  class TokenLocator
    attr_reader :tokens

    def initialize()
      @tokens = {}
    end

    def register_token(token)
      tokens[token[0]] = token
    end

    def token(id)
      tokens[id] or raise
    end

    def token_range(id)
      _, _, offset, value = token(id)

      offset..(offset+value.size)
    end

    def string(id)
      tok = token(id) or raise
      tok[3]
    end
  end
end
