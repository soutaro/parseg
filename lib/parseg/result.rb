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

    def has_error?
      tree.error_tree? ? true : !skip_tokens.empty?
    end

    def tree_range_for_deleted_token(token, tree = self.tree)
      tree.each do |tree|
        first_token = tree.first_token
        last_token = tree.last_token

        if first_token && last_token
          if first_token <= token && token <= last_token
            case tree
            when Tree::NonTerminalTree
              sub_trees = [tree.value] if tree.value
            when Tree::AlternationTree
              sub_trees = [tree.value]
            when Tree::OptionalTree
              sub_trees = [tree.value] if tree.value
            when Tree::RepeatTree
              sub_trees = tree.values
            when Tree::TokenTree, Tree::EmptyTree, Tree::MissingTree
              # nop
            end

            if sub_trees
              sub_trees.each do |sub|
                if range = tree_range_for_deleted_token(token, sub)
                  return range
                end
              end
            end

            if tree.is_a?(Tree::NonTerminalTree) && tree.expression.non_terminal.block?
              return factory.token_range(first_token).begin...factory.token_range(last_token).end
            end
          end
        end
      end

      nil
    end
  end
end
