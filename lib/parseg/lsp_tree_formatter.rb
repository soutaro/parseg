module Parseg
  class LspTreeFormatter
    LSP = LanguageServer::Protocol

    attr_reader :locator, :buffer

    def initialize(locator, buffer)
      @locator = locator
      @buffer = buffer
    end

    def format_tree(tree, last_position:)
      tree.each.with_object(
        [] #: Array[LanguageServer::Protocol::Interface::DocumentSymbol]
      ) do |tree, symbols|
        new_symbols =
          case tree
          when Tree::EmptyTree
            []
          when Tree::TokenTree
            id, type, offset, string = locator.token(tree.token_id)

            start_pos = buffer.pos_to_loc(offset)
            end_pos = buffer.pos_to_loc(offset + string.size)

            [
              LSP::Interface::DocumentSymbol.new(
                name: string,
                detail: type.to_s,
                kind: LSP::Constant::SymbolKind::FIELD,
                range: {
                  start: { line: start_pos[0] - 1, character: start_pos[1] },
                  end: { line: end_pos[0] - 1, character: end_pos[1] }
                },
                selection_range: {
                  start: { line: start_pos[0] - 1, character: start_pos[1] },
                  end: { line: end_pos[0] - 1, character: end_pos[1] }
                }
              )
            ]
          when Tree::NonTerminalTree
            if tree.value && (children = format_tree(tree.value, last_position: last_position)) && !children.empty?
              first_child = children.first or raise
              last_child = children.last or raise

              [
                LSP::Interface::DocumentSymbol.new(
                  name: tree.expression.non_terminal.name.to_s,
                  kind: LSP::Constant::SymbolKind::CONSTRUCTOR,
                  range: {
                    start: first_child.range[:start],
                    end: last_child.range[:end],
                  },
                  selection_range: {
                    start: first_child.selection_range[:start],
                    end: last_child.selection_range[:end]
                  },
                  children: children
                )
              ]
            else
              [
                LSP::Interface::DocumentSymbol.new(
                  name: tree.expression.non_terminal.name.to_s,
                  kind: LSP::Constant::SymbolKind::NULL,
                  range: {
                    start: last_position,
                    end: last_position,
                  },
                  selection_range: {
                    start: last_position,
                    end: last_position
                  }
                )
              ]
            end
          when Tree::OptionalTree
            if tree.value
              format_tree(tree.value, last_position: last_position)
            else
              []
            end
          when Tree::AlternationTree
            format_tree(tree.value, last_position: last_position)
          when Tree::RepeatTree
            children = []

            tree.values.each do |child|
              childs = format_tree(child, last_position: last_position)
              children.push(*childs)
              if last_child = childs.last
                last_position = last_child.range[:end]
              end
            end

            unless children.empty?
              first_child = children.first or raise
              last_child = children.last or raise

              [
                LSP::Interface::DocumentSymbol.new(
                  name: "[Repeat]",
                  kind: LSP::Constant::SymbolKind::ARRAY,
                  range: {
                    start: first_child.range[:start],
                    end: last_child.range[:end],
                  },
                  selection_range: {
                    start: first_child.selection_range[:start],
                    end: last_child.selection_range[:end]
                  },
                  children: children
                )
              ]
            end
          when Tree::MissingTree
            if id = tree.token
              range = locator.token_range(id)
              start_pos = buffer.pos_to_loc(range.begin)
              end_pos = buffer.pos_to_loc(range.end)

              [
                LSP::Interface::DocumentSymbol.new(
                  detail: "Expected one of: #{tree.expression.first_tokens}",
                  name: "#{locator.string(id)} (#{locator.token(id)[1]})",
                  tags: [1],
                  kind: LSP::Constant::SymbolKind::ENUM_MEMBER,
                  range: {
                    start: { line: start_pos[0] - 1, character: start_pos[1] },
                    end: { line: end_pos[0] - 1, character: end_pos[1] }
                  },
                  selection_range: {
                    start: { line: start_pos[0] - 1, character: start_pos[1] },
                    end: { line: end_pos[0] - 1, character: end_pos[1] }
                  }
                )
              ]
            else
              [
                LSP::Interface::DocumentSymbol.new(
                  detail: "Expected one of: #{tree.expression.first_tokens}",
                  name: "[EOF]",
                  tags: [1],
                  kind: LSP::Constant::SymbolKind::ENUM_MEMBER,
                  range: {
                    start: last_position,
                    end: last_position
                  },
                  selection_range: {
                    start: last_position,
                    end: last_position
                  }
                )
              ]
            end
          end

        if new_symbols
          unless new_symbols.empty?
            symbol = new_symbols.last or raise
            last_position = symbol.range[:end]
            symbols.push(*new_symbols)
          end
        end
      end
    end
  end
end
