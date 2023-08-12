module Parseg
  module Tree
    class Base
      attr_reader :expression

      def token_range
        ft = nil #: Integer?
        lt = nil #: Integer?

        each_token do |token|
          ft = token unless ft
          lt = token
        end

        if ft && lt
          ft..lt
        end
      end

      def first_token
        token_range&.begin
      end

      def last_token
        token_range&.end
      end

      def range(locator)
        tr = token_range

        if tr
          first_range = locator.token_range(tr.begin)
          last_range = locator.token_range(tr.end)
          first_range.begin ... last_range.end
        end
      end

      def first_token_range(locator)
        if token = first_token
          locator.token_range(token)
        end
      end

      def last_token_range(locator)
        if token = last_token
          locator.token_range(token)
        end
      end

      # def error_tree?
      #   ets = error_trees([])
      #   unless ets.empty?
      #     ets
      #   end
      # end

      # def immediate_error_tree?
      #   if errors = error_tree?
      #     immediate_errors = errors.filter {|tree| tree.is_a?(MissingTree) } #: Array[MissingTree]
      #     unless immediate_errors.empty?
      #       immediate_errors
      #     end
      #   end
      # end

      # def error_trees(errors)
      #   if next_tree
      #     next_tree.error_trees(errors)
      #   else
      #     errors
      #   end
      # end
    end

    class TokenTree < Base
      attr_reader :token_id

      def initialize(expr, token_id)
        @expression = expr
        @token_id = token_id
      end

      def each_token(&block)
        if block
          yield token_id
        else
          enum_for :each_token
        end
      end
    end

    class NonTerminalTree < Base
      attr_reader :tree

      def initialize(expr, tree)
        @expression = expr
        @tree = tree
      end

      def each_token(&block)
        if block
          tree.each do |tree|
            tree.each_token(&block)
          end
        else
          enum_for :each_token
        end
      end
    end

    class EmptyTree < Base
      def initialize(expr)
        @expression = expr
      end

      def each_token
        if block_given?
        else
          enum_for :each_token
        end
      end
    end

    class AlternationTree < Base
      attr_reader :tree

      def initialize(expr, tree)
        @expression = expr
        @tree = tree
      end

      def each_token(&block)
        if block
          tree.each do |t|
            t.each_token(&block)
          end
        else
          enum_for :each_token
        end
      end
    end

    class RepeatTree < Base
      attr_reader :trees

      def initialize(expr, trees)
        @expression = expr
        @trees = trees
      end

      def each_content(&block)
        if block
          trees.each_with_index do |tree, index|
            if index.even?
              yield tree
            end
          end
        else
          enum_for :each_content
        end
      end

      def each_separator(&block)
        if block
          trees.each_with_index do |tree, index|
            if index.odd?
              yield tree
            end
          end
        else
          enum_for :each_separator
        end
      end

      def each_token(&block)
        if block
          trees.each do |tree|
            tree.each do |t|
              t.each_token &block
            end
          end
        else
          enum_for :each_token
        end
      end
    end

    class OptionalTree < Base
      attr_reader :tree

      def initialize(expr, tree)
        @expression = expr
        @tree = tree
      end

      def each_token(&block)
        if block
          tree.each do |t|
            t.each_token(&block)
          end
        else
          enum_for :each_token
        end
      end
    end

    class MissingTree < Base
      attr_reader :token

      def initialize(expr, token)
        @expression = expr
        @token = token
      end
    end
  end
end
