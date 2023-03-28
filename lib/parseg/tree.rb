module Parseg
  module Tree
    class Base
      attr_reader :next_tree, :expression

      def range(locator)
        unless self.is_a?(MissingTree)
          fr = first_range(locator)
        end

        if next_tree
          nr = next_tree.range(locator)
        end

        if fr && nr
          fr.begin .. nr.end
        else
          fr || nr
        end
      end

      def each(&block)
        if block
          yield(_ = self)
          if next_tree
            next_tree.each(&block)
          end
        else
          enum_for :each
        end
      end

      def error_tree?
        ets = error_trees([])
        unless ets.empty?
          ets
        end
      end

      def immediate_error_tree?
        if errors = error_tree?
          immediate_errors = errors.filter {|tree| tree.is_a?(MissingTree) } #: Array[MissingTree]
          unless immediate_errors.empty?
            immediate_errors
          end
        end
      end

      def error_trees(errors)
        if next_tree
          next_tree.error_trees(errors)
        else
          errors
        end
      end
    end

    class TokenTree < Base
      attr_reader :token_id

      def initialize(expr, token_id, next_tree:)
        @expression = expr
        @token_id = token_id
        @next_tree = next_tree
      end

      def first_range(locator)
        locator.token_range(token_id)
      end
    end

    class NonTerminalTree < Base
      attr_reader :value

      def initialize(expr, value, next_tree:)
        @expression = expr
        @value = value
        @next_tree = next_tree
      end

      def first_range(locator)
        if value
          value.first_range(locator)
        end
      end

      def error_trees(errors)
        if value && value.error_tree?
          errors << value
        end

        super(errors)
      end
    end

    class EmptyTree < Base
      def initialize(expr, next_tree:)
        @expression = expr
        @next_tree = next_tree
      end

      def first_range(locator)
        nil
      end
    end

    class AlternationTree < Base
      attr_reader :value

      def initialize(expr, value, next_tree:)
        @expression = expr
        @value = value
        @next_tree = next_tree
      end

      def first_range(locator)
        value.first_range(locator)
      end

      def error_trees(errors)
        if value && value.error_tree?
          errors << value
        end

        super(errors)
      end
    end

    class RepeatTree < Base
      attr_reader :values

      def initialize(expr, values, next_tree:)
        @expression = expr
        @values = values
        @next_tree = next_tree
      end

      def each_non_terminal(&block)
        if block
          values.each do |value|
            if value.expression == expression.content
              yield value
            end
          end
        else
          enum_for :each_non_terminal
        end
      end

      def each_separator(&block)
        if block
          values.each do |value|
            if value.expression == expression.separator
              yield value
            end
          end
        else
          enum_for :each_separator
        end
      end

      def first_range(locator)
        first = values.first or raise
        first.first_range(locator)
      end

      def error_trees(errors)
        if values.any? {|t| t.error_tree? }
          errors << self
        end

        super(errors)
      end
    end

    class OptionalTree < Base
      attr_reader :value

      def initialize(expr, value, next_tree:)
        @value = value
        @expression = expr
        @next_tree = next_tree
      end

      def first_range(locator)
        if value
          value.first_range(locator)
        end
      end

      def error_trees(errors)
        if value && value.error_tree?
          errors << self
        end

        super(errors)
      end
    end

    class MissingTree < Base
      attr_reader :token

      def initialize(expr, token, next_tree:)
        @expression = expr
        @token = token
        @next_tree = next_tree
      end

      def first_range(locator)
        if token
          locator.token_range(token)
        end
      end

      def error_trees(errors)
        errors << self
        super(errors)
      end
    end
  end
end
