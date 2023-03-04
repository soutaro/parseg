module Parseg
  class Result
    attr_reader :token_locator, :tree, :skip_tokens

    def initialize(tree:, token_locator:, skip_tokens:)
      @tree = tree
      @token_locator = token_locator
      @skip_tokens = skip_tokens
    end
  end
end
