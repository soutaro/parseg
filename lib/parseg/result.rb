module Parseg
  class Result
    attr_reader :token_locator, :tree

    def initialize(tree:, token_locator:)
      @tree = tree
      @token_locator = token_locator
    end
  end
end
