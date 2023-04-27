module Parseg
  class ParsingSession
    attr_reader :tokenizer, :grammar, :last_successful_result, :start

    attr_accessor :error_tolerant_enabled, :skip_unknown_tokens_enabled, :change_based_error_recovery_enabled

    def initialize(tokenizer:, grammar:, start:)
      @tokenizer = tokenizer
      @grammar = grammar
      @start = start
    end

    def start_symbol
      grammar.non_terminals.fetch(start)
    end

    def update(changes)
      last = last_result?&.factory || TokenFactory.new(tokenizer: tokenizer, status: "")
      factory = last.update(changes)

      result = Parser.new(grammar: grammar, factory: factory.reset).yield_self do |parser|
        parser.error_tolerant_enabled = error_tolerant_enabled
        parser.skip_unknown_tokens_enabled = skip_unknown_tokens_enabled
        parser.parse(start_symbol)
      end

      if result.has_error?
        if change_based_error_recovery_enabled && last_successful_result
          deleted_tokens = factory.deleted_tokens

          if factory.inserted_tokens.empty? && !deleted_tokens.empty?
            incoming_changes = factory.incoming_changes

            factory = last_successful_result.factory
            deleted_tokens.each_key do |token_id|
              if range = last_successful_result.tree_range_for_deleted_token(token_id)
                factory = factory.with_additional_change(range)
              end
            end
            factory = factory.update(incoming_changes)
          end

          result = Parseg::Parser.new(grammar: grammar, factory: factory).yield_self do |parser|
            parser.error_tolerant_enabled = true
            parser.skip_unknown_tokens_enabled = true
            parser.parse(start_symbol)
          end
        end
      end

      @last_result = result
      @last_successful_result = result unless result.has_error?

      result
    end

    def last_result
      @last_result or raise
    end

    def last_result?
      @last_result
    end

    def last_source
      last_result.factory.source
    end
  end
end
