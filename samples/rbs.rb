include Parseg

def define_tokenizer(**defn)
  -> (string) {
    tokenizer = Object.new

    scan = StringScanner.new(string)

    tokenizer.singleton_class.define_method(:next_token) do
      while str = scan.scan(/(\s+)|(#[^\n]*)/)
        # nop
      end

      defn.each do |type, regexp|
        if string = scan.scan(regexp)
          return [type, scan.charpos, string]
        end
      end

      return nil
    end

    tokenizer.singleton_class.define_method(:all_tokens) do
      toks = []

      while tok = next_token
        toks << tok
      end

      toks
    end

    tokenizer
  }
end

tokenizer = define_tokenizer(
  kLPAREN: /\(/,
  kRPAREN: /\)/,
  kCOLON2: /::/,
  tNAMESPACE: /([A-Z]\w*::)+/,
  kCOLON: /:/,
  kARROW: /\-\>/,
  kVOID: /void/,
  kUNTYPED: /untyped/,
  kNIL: /nil/,
  kSELFQ: /self\?/,
  kSELF: /self/,
  kCLASS: /class/,
  kMODULE: /module/,
  kSINGLETON: /singleton/,
  kBOOL: /bool/,
  kDEF: /def/,
  kBAR: /\|/,
  kAND: /\&/,
  kLT: /\</,
  kEQ: /\=/,
  kEND: /end/,
  kDOT3: /\.\.\./,
  kLBRACKET: /\[/,
  kRBRACKET: /\]/,
  kLBRACE: /\{/,
  kRBRACE: /\}/,
  kCOMMA: /,/,
  kDOT: /\./,
  kQUESTION: /\?/,
  kSTAR2: /\*\*/,
  kSTAR: /\*/,
  tUKEYWORD: /[A-Z]\w*:/,
  tLKEYWORD: /[a-z]\w*:/,
  tULKEYWORD: /_[a-z]\w*:/,
  tUIDENT: /[A-Z]\w*/,
  tLIDENT: /[a-z]\w*/,
  tULIDENT: /_[A-Z]\w*/,
  tATIDENT: /@[a-zA-Z]\w*/
)

grammar = Grammar.new() do |grammar|
  grammar[:simple_type].rule = Alt(
    T(:tLPAREN) + NT(:type) + T(:tRPAREN),
    NT(:base_type),
    NT(:type_name) + Opt(
      T(:kLBRACKET) + Repeat(NT(:type)).with(separator: T(:kCOMMA)) + T(:kRBRACKET)
    ),
    T(:kSINGLETON) + T(:kLPAREN) + NT(:type_name) + T(:kRPAREN),
    T(:kLBRACKET) + Opt(Repeat(NT(:type)).with(separator: T(:kCOMMA)))  + T(:kRBRACKET)
  )

  grammar[:type_name].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tLIDENT), T(:tULIDENT))

  grammar[:base_type].rule = Alt(
    T(:kVOID), T(:kUNTYPED), T(:kNIL), T(:kSELF), T(:kSELF), T(:kBOOL)
  )

  grammar[:optional_type].rule = NT(:simple_type) + Opt(T(:kQUESTION))

  grammar[:intersection_type].rule =
    Repeat(NT(:optional_type)).with(separator: T(:kAMD), trailing: false, leading: false)

  grammar[:union_type].rule =
    Repeat(NT(:intersection_type)).with(separator: T(:kBAR), trailing: false, leading: false)

  grammar[:type].rule = NT(:union_type)

  grammar[:return_type].rule = NT(:optional_type)

  grammar[:method_type].rule = Opt(NT(:type_params)) + NT(:params) + Opt(NT(:block)) + T(:kARROW) + NT(:return_type)

  grammar[:type_params].rule =
    T(:kLBRACKET) + Repeat(NT(:type_param)).with(separator: T(:kCOMMA)) + T(:kRBRACKET)

  grammar[:type_param].rule =
    T(:tUIDENT) + Opt(T(:kLT) + NT(:upper_bound))

  grammar[:upper_bound].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tULIDENT))

  grammar[:block].rule = Opt(T(:kQUESTION)) + T(:kLBRACE) + NT(:params) + Opt(NT(:block_self_binding)) + T(:kARROW) + NT(:return_type) + T(:kRBRACE)

  grammar[:block_self_binding].rule = T(:kLBRACKET) + T(:kSELF) + T(:kCOLON) + NT(:type) + T(:kRBRACKET)

  grammar[:params].rule = T(:kLPAREN) + Opt(NT(:required_params)) + T(:kRPAREN)

  grammar[:required_params].rule = Alt(
    NT(:required_param) + Opt(T(:kCOMMA) + NT(:required_params)),
    NT(:question_param) + Opt(T(:kCOMMA) + NT(:question_params)),
    NT(:rest_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
    NT(:keyword_params)
  )

  grammar[:question_params].rule = Alt(
    T(:kQUESTION) + Alt(
      NT(:required_param) + Opt(T(:kCOMMA) + NT(:question_params)),
      NT(:keyword_param) + Opt(T(:kCOMMA) + NT(:keyword_params))
    ),
    NT(:rest_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
    NT(:keyword_params)
  )

  grammar[:keyword_params].rule = Alt(
    NT(:keyword_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
    T(:kQUESTION) + NT(:keyword_param) + Opt(T(:kCOMMA) + NT(:keyword_params)),
    NT(:keyword_rest_param)
  )

  grammar[:required_param].rule = NT(:type) + Opt(T(:tLIDENT))

  grammar[:question_param].rule = T(:kQUESTION) + Alt(NT(:required_param), NT(:keyword_param))

  grammar[:keyword_param].rule = Alt(T(:tLKEYWORD), T(:tUKEYWORD), T(:tULKEYWORD)) + NT(:type) + Opt(T(:tLIDENT))

  grammar[:rest_param].rule = T(:kSTAR) + NT(:type) + Opt(T(:tLIDENT))

  grammar[:keyword_rest_param].rule = T(:kSTAR2) + NT(:type) + Opt(T(:tLIDENT))

  grammar[:module_name].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + T(:tUIDENT)

  type_names = -> (module_name:, interface_name:, alias_name:) {
    list = []

    list << T(:tUIDENT) if module_name
    list << T(:tLIDENT) if alias_name
    list << T(:tULIDENT) if interface_name

    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(*list)
  }

  grammar[:module_decl].rule =
    T(:kMODULE) + NT(:module_name) + Alt(
      NT(:module_alias_rhs),
      Opt(NT(:type_params)) + NT(:module_decl_rhs)
    )

  grammar[:module_alias_rhs].rule =
    T(:kEQ) + NT(:module_name)

  grammar[:module_decl_rhs].rule =
    Opt(T(:kCOLON) + NT(:module_self_decl)) + NT(:module_members) + T(:kEND)

  grammar[:module_self_decl].rule =
    Repeat(NT(:module_self_constraint)).with(separator: T(:kCOMMA))

  grammar[:module_self_constraint].rule =
    type_names[module_name: true, interface_name: true, alias_name: false] + Opt(
      T(:kLBRACKET) + Repeat(NT(:type)).with(separator: T(:kCOMMA)) + T(:kRBRACKET)
    )

  grammar[:module_members].rule = Opt(
    Repeat(
      Alt(
        NT(:module_decl),
        NT(:constant_decl),
        NT(:ivar_member),
        NT(:self_ivar_member),
        NT(:method_definition),
      )
    )
  )

  grammar[:ivar_member].rule = T(:tATIDENT) + T(:kCOLON) + NT(:simple_type)

  grammar[:self_ivar_member].rule = T(:kSELF) + T(:kDOT) + T(:tATIDENT) + T(:kCOLON) + NT(:simple_type)

  grammar[:constant_decl].rule = Alt(
    T(:tUIDENT) + T(:kCOLON) + NT(:simple_type),
    T(:tUKEYWORD) + NT(:simple_type),
  )

  grammar[:method_definition].rule =
    T(:kDEF) + Opt(T(:kSELF) + T(:kDOT)) + Alt(
      NT(:method_name) + T(:kCOLON),
      T(:tUKEYWORD),
      T(:tLKEYWORD),
      T(:tULKEYWORD),
    ) + NT(:method_types)

  grammar[:method_name].rule = T(:tLIDENT)

  grammar[:method_types].rule =
    NT(:method_type) + Opt(
      T(:kBAR) + Alt(
        T(:kDOT3),
        NT(:method_types)
      )
    )
end

[tokenizer, grammar]
