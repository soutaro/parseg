module Parseg
  class Result
    attr_reader :factory, :tree, :skip_tokens

    def initialize(tree:, factory:, skip_tokens:)
      @tree = tree
      @factory = factory
      @skip_tokens = skip_tokens
    end

    def each_error_tree(&block)
      if block
        each_tree do |tree|
          case tree
          when Tree::MissingTree
            yield tree
          end
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
          tree.tree.each do |t|
            each_tree(t, &block)
          end
        when Tree::RepeatTree
          tree.trees.each do |tree|
            tree.each do |t|
              each_tree(t, &block)
            end
          end
        when Tree::OptionalTree
          tree.tree.each do |t|
            each_tree(t, &block)
          end
        when Tree::AlternationTree
          tree.tree.each do |t|
            each_tree(t, &block)
          end
        end
      else
        enum_for :each_tree
      end
    end

    def has_error?
      each_error_tree.any?
    end

    def tree_list(token_range, tree = self.tree, array = [])
      tree_range = tree.range(factory)
      if tree_range
        if tree_range.begin <= token_range.begin && token_range.end <= tree_range.end
          array.unshift(tree)

          before_size = array.size

          case tree
          when Tree::RepeatTree
            tree.trees.each do |tree|
              tree.each do |t|
                tree_list(token_range, t, array)
                return array if array.size > before_size
              end
            end
          when Tree::NonTerminalTree, Tree::AlternationTree, Tree::OptionalTree
            tree.tree.each do |t|
              tree_list(token_range, t, array)
              return array if array.size > before_size
            end
          end
        end
      end

      array
    end

    def tree_range_for_deleted_token(token, tree = self.tree)
      trees = tree_list(factory.token_range(token))
      block_tree = trees.find do |t|
        case t
        when Tree::NonTerminalTree
          t.expression.non_terminal.block?
        end
      end

      if block_tree
        block_tree.range(factory)
      end
    end
  end
end
