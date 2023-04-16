module Parseg
  class TokenFactory
    attr_reader :tokenizer, :input, :prev, :changes, :current_token, :current_id, :enumerator
    attr_reader :tokens

    def initialize(tokenizer:, input: nil, prev: nil, changes: [])
      @tokenizer = tokenizer
      if input
        @prev = input
      end
      if prev
        @prev = prev
      end
      @changes = changes

      prev_input =
        case prev()
        when String
          prev()
        else
          prev().input
        end

      @input = changes.each.with_object(prev_input.dup) do |change, string|
        str, start_loc, end_loc = change

        buf = RBS::Buffer.new(name: "", content: string)
        start_pos = buf.loc_to_pos(start_loc)
        end_pos = buf.loc_to_pos(end_loc)

        string[start_pos...end_pos] = str
      end

      @max_id = 0

      @tokens = []
      tokenizer.each_token(@input) do |tok|
        if tok
          @tokens << [next_id, tok]
        end
      end

      @enumerator = Enumerator.new do |y|
        @tokens.each do |id, tok|
          y << [id, tok]
        end
        y << nil
      end

      advance_token()
    end

    def next_id
      @max_id += 1
    end

    def advance_token
      if (new_id, tok = enumerator.next)
        @current_id = new_id
        @current_token = tok

        [new_id, tok]
      else
        @current_id = nil
        @current_token = nil
      end
    rescue StopIteration
      @current_id = nil
      @current_token = nil
    end

    def advance_token!
      advance_token or raise
    end

    def current_token!
      current_token or raise
    end

    def current_id!
      current_id or raise
    end

    def current_type
      if current_token
        current_token[0]
      end
    end

    def current_type!
      current_type or raise
    end

    def current_range
      if id = current_id
        token_range(id)
      end
    end

    def current_range!
      current_range or raise
    end

    def token_range(id)
      tok = token(id)
      _, start, str = tok
      start...(start + str.size)
    end

    def token_string(id)
      if (_, _, string = token(id))
        string
      end
    end

    def token_string!(id)
      token_string(id) or raise
    end

    def token_type(id)
      if (type, _, _ = token(id))
        type
      end
    end

    def token_type!(id)
      token_type(id) or raise
    end

    def token(id)
      (_, tok = tokens.find {|tok_id, tok| tok_id == id }) or raise
      tok
    end

    def surrounding_changed_range
    first_change, *changes = self.changes()
    return unless first_change

    buf = RBS::Buffer.new(name: "", content: input)

    @surrounding_changed_range ||= begin
        str, start_loc, end_loc = first_change

        surrounding_begin = buf.loc_to_pos(start_loc)
        surrounding_end = surrounding_begin + str.size

        changes.each do |(str, start_loc, end_loc)|
          be = buf.loc_to_pos(start_loc)
          changed = be...(be + str.size)

          if surrounding_begin > changed.begin
            surrounding_begin  = changed.begin
          end

          if surrounding_end < changed.end
            surrounding_end = changed.end
          end
        end

        surrounding_begin ... surrounding_end
      end
    end

    def token_changed?(id = current_id!)
      range = token_range(id)

      case sr = surrounding_changed_range
      when Range
        return false if range.end < sr.begin
        return false if range.begin > sr.end
        true
      when nil
        false
      end
    end

    def update(changes)
      case self.prev
      when String
        TokenFactory.new(tokenizer: tokenizer, prev: self, changes: self.changes + changes)
      else
        TokenFactory.new(tokenizer: tokenizer, prev: self.prev, changes: self.changes + changes)
      end

    end

    def reset()
      TokenFactory.new(tokenizer: tokenizer, prev: self.input, changes: [])
    end

    def inserted_tokens
      tokens.each.with_object({}) do |(id, token), tokens| #$ Hash[Integer, token]
        if token_changed?(id)
          tokens[id] = token
        end
      end
    end

    def deleted_tokens
      case prev
      when String
        {}
      else
        range =  surrounding_changed_range
        if range
          if range.begin == range.end

          else
            inserteds = inserted_tokens()
            prefix = tokens.take_while {|id, _| !inserteds.key?(id) }
            suffix = tokens.size - prefix.size - inserteds.size

            prev.tokens.drop(prefix.size).reverse.drop(suffix).reverse.to_h
          end
        end
      end
    end
  end
end
