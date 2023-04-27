module Parseg
  class TokenFactory
    FactoryStatus = _ = Struct.new(:last_tokens, :last_input, :incoming_changes)

    attr_reader :tokenizer, :status, :current_token, :current_id, :enumerator
    attr_reader :tokens

    def initialize(tokenizer:, status:)
      @tokenizer = tokenizer
      @status = status

      @max_id = 0

      @tokens = []
      tokenizer.each_token(source) do |tok|
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
      @surrounding_changed_range ||= begin
        changes = incoming_changes.dup

        return if changes.empty?

        buf = RBS::Buffer.new(name: "", content: source)

        (str, start_loc, end_loc = changes.shift) or raise

        surrounding_begin = buf.loc_to_pos(start_loc)
        surrounding_end = surrounding_begin + str.size

        changes.each do |(str, start_loc, end_loc)|
          be = buf.loc_to_pos(start_loc)
          en = buf.loc_to_pos(end_loc)
          changed = be...(be + str.size)

          range_size = en - be

          if surrounding_begin > changed.begin
            surrounding_begin  = changed.begin
          end

          case
          when range_size < str.size
            # inserted
            if surrounding_end < changed.end
              surrounding_end = changed.end
            end
          when range_size > str.size
            # deleted
            if be <= surrounding_end && surrounding_end <= en
              surrounding_end = changed.end
            end
          end
        end

        surrounding_begin ... surrounding_end
      end
    end

    def incoming_changes
      case status
      when String
        []
      else
        status.incoming_changes
      end
    end

    def token_changed?(id = current_id!)
      range = token_range(id)

      case sr = surrounding_changed_range
      when Range
        Parseg.logger.debug {
          {
            token: token_type(id),
            surrounding_range: sr,
            token_range: range
          }.inspect
        }
        return false if range.end <= sr.begin
        return false if range.begin >= sr.end
        true
      when nil
        false
      end
    end

    def update(changes)
      new_status =
        case status
        when String
          FactoryStatus.new(tokens, status, changes)
        when FactoryStatus
          FactoryStatus.new(status.last_tokens, status.last_input, status.incoming_changes + changes)
        else
          raise
        end

      TokenFactory.new(tokenizer: tokenizer, status: new_status)
    end

    def reset()
      TokenFactory.new(tokenizer: tokenizer, status: source)
    end

    def source
      @source ||=
        case status
        when String
          status
        else
          status.incoming_changes.each.with_object(status.last_input.dup) do |change, string|
            str, start_loc, end_loc = change

            buf = RBS::Buffer.new(name: "", content: string)
            start_pos = buf.loc_to_pos(start_loc)
            end_pos = buf.loc_to_pos(end_loc)

            string[start_pos...end_pos] = str
          end
        end
    end

    def inserted_tokens
      tokens.each.with_object({}) do |(id, token), tokens| #$ Hash[Integer, token]
        if token_changed?(id)
          tokens[id] = token
        end
      end
    end

    def deleted_tokens
      case status
      when String
        {}
      else
        range = surrounding_changed_range or raise

        inserteds = inserted_tokens()
        prefix = [] #: Array[[Integer, token]]
        changed = [] #: Array[[Integer, token]]
        suffix = [] #: Array[[Integer, token]]

        tokens.each do |pair|
          token_range = token_range(pair[0])

          case
          when token_range.end <= range.begin
            prefix << pair
          when range.end <= token_range.begin
            suffix << pair
          else
            changed << pair
          end
        end

        last_tokens = status.last_tokens
        last_tokens = last_tokens.drop(prefix.size)
        size = last_tokens.size - suffix.size
        if size > 0
          last_tokens = last_tokens.take(size)
        else
          last_tokens.clear
        end

        last_tokens.to_h
      end
    end

    def with_additional_change(range)
      string = source[range.begin...range.end] or raise
      buf = RBS::Buffer.new(name: "", content: source)
      change = [
        string,
        buf.pos_to_loc(range.begin),
        buf.pos_to_loc(range.end)
      ]  #: change

      update([change])
    end
  end
end
