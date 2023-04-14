module Parseg
  class Result
    attr_reader :factory, :tree, :skip_tokens

    def initialize(tree:, factory:, skip_tokens:)
      @tree = tree
      @factory = factory
      @skip_tokens = skip_tokens
    end

    def each_error_tree(tree = self.tree, &block)
      if block
        case tree
        when Tree::MissingTree
          yield tree
        when Tree::NonTerminalTree
          each_error_tree(tree.value, &block) if tree.value
        when Tree::RepeatTree
          tree.values.each do |tree|
            each_error_tree(tree, &block)
          end
        when Tree::OptionalTree
          each_error_tree(tree.value, &block) if tree.value
        when Tree::AlternationTree
          each_error_tree(tree.value, &block) if tree.value
        end

        if tree.next_tree
          each_error_tree(tree.next_tree, &block)
        end
      else
        enum_for :each_error_tree
      end
    end

    def each_tree(tree = self.tree, &block)
      if block
        yield tree

        case tree
        when Tree::NonTerminalTree
          each_tree(tree.value, &block) if tree.value
        when Tree::RepeatTree
          tree.values.each do |tree|
            each_tree(tree, &block)
          end
        when Tree::OptionalTree
          each_tree(tree.value, &block) if tree.value
        when Tree::AlternationTree
          each_tree(tree.value, &block) if tree.value
        end

        if tree.next_tree
          each_tree(tree.next_tree, &block)
        end
      else
        enum_for :each_tree
      end
    end
  end
end
