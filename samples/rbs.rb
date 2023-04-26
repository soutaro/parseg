include Parseg

def define_tokenizer(**defn)
  tokenizer = Object.new

  tokenizer.singleton_class.define_method(:each_token) do |string, &block|
    scan = StringScanner.new(string)

    while true
      while str = scan.scan(/(\s+)|(#[^\n]*)/)
        # nop
      end

      break if scan.eos?

      failed = defn.each do |type, regexp|
        if string = scan.scan(regexp)
          block.call [type, scan.charpos - string.size, string]
          break false
        end
      end

      if failed
        string = scan.scan(/[^\s]+/)
        block.call [:UNKNOWN, scan.charpos - string.size, string]
      end
    end

    block.call nil
  end

  tokenizer.singleton_class.define_method(:all_tokens) do
    toks = []

    while tok = next_token
      toks << tok
    end

    toks
  end

  tokenizer
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
  kUNCHECKED: /unchecked/,
  kINCLUDE: /include/,
  kEXTEND: /extend/,
  kPREPEND: /prepend/,
  kIN: /in/,
  kOUT: /out/,
  kALIAS: /alias/,
  kTYPE: /type/,
  kUSE: /use/,
  kAS: /as/,
  kATTRREADER: /attr_reader/,
  kATTRACCESSOR: /attr_accessor/,
  kATTRWRITER: /attr_writer/,
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
  tATIDENT: /@[a-zA-Z]\w*/,
  tGIDENT: /\$[a-zA-Z]\w*/
)

grammar = Parseg::Grammar.new() do |grammar|
  grammar[:simple_type].rule = Alt(
    T(:kLPAREN) + NT(:type) + T(:kRPAREN),
    NT(:base_type),
    NT(:type_name) + Opt(
      T(:kLBRACKET) + Repeat(NT(:type), T(:kCOMMA)) + T(:kRBRACKET)
    ),
    T(:kSINGLETON) + T(:kLPAREN) + NT(:type_name) + T(:kRPAREN),
    T(:kLBRACKET) + Opt(Repeat(NT(:type), T(:kCOMMA))) + T(:kRBRACKET)
  )

  grammar[:type_name].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tLIDENT), T(:tULIDENT))

  grammar[:base_type].rule = Alt(
    T(:kVOID), T(:kUNTYPED), T(:kNIL), T(:kSELF), T(:kBOOL)
  )

  grammar[:optional_type].rule = NT(:simple_type) + Opt(T(:kQUESTION))

  grammar[:intersection_type].rule =
    Repeat(NT(:optional_type), T(:kAMD))

  grammar[:union_type].rule =
    Repeat(NT(:intersection_type), T(:kBAR))

  grammar[:type].rule = NT(:union_type)

  grammar[:return_type].rule = NT(:optional_type)

  grammar[:method_type].rule = Opt(NT(:type_params)) + Opt(NT(:params)) + Opt(NT(:block)) + T(:kARROW) + NT(:return_type)

  grammar[:type_params].rule =
    T(:kLBRACKET) + Repeat(NT(:type_param), T(:kCOMMA)) + T(:kRBRACKET)

  grammar[:type_param].rule =
    Opt(T(:kUNCHECKED)) + Opt(Alt(T(:kIN), T(:kOUT))) + T(:tUIDENT) + Opt(T(:kLT) + NT(:upper_bound))

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

  type_names = -> (module_name: true, interface_name: true, alias_name: true) {
    list = []

    list << T(:tUIDENT) if module_name
    list << T(:tLIDENT) if alias_name
    list << T(:tULIDENT) if interface_name

    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(*list)
  }

  grammar[:module_decl].cut!.rule =
    T(:kMODULE) + NT(:module_name) + Alt(
      NT(:module_alias_rhs),
      Opt(NT(:type_params)) + NT(:module_decl_rhs)
    )

  grammar[:module_alias_rhs].rule =
    T(:kEQ) + NT(:module_name)

  grammar[:module_decl_rhs].rule =
    Opt(T(:kCOLON) + NT(:module_self_decl)) + NT(:module_members) + T(:kEND)

  grammar[:module_self_decl].rule =
    Repeat(NT(:module_self_constraint), T(:kCOMMA))

  grammar[:module_self_constraint].rule =
    type_names[alias_name: false] + Opt(
      T(:kLBRACKET) + Repeat(NT(:type), T(:kCOMMA)) + T(:kRBRACKET)
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

  grammar[:attribute_name].rule = T(:tLIDENT)

  grammar[:method_types].rule =
    Alt(
      T(:kDOT3),
      NT(:method_type) + Opt(T(:kBAR) + NT(:method_types))
    )

  grammar[:alias_decl].rule =
    T(:kALIAS) + Alt(
      T(:kSELF) + T(:kDOT) + NT(:method_name) + T(:kSELF) + T(:kDOT) + NT(:method_name),
      NT(:method_name) + NT(:method_name)
    )

  grammar[:type_alias_decl].rule =
    T(:kTYPE) + type_names[module_name: false, interface_name: false] + Opt(NT(:type_params)) + T(:kEQ) + NT(:simple_type)

  grammar[:global_decl].rule =
    T(:tGIDENT) + T(:kCOLON) + NT(:simple_type)

  attribute = -> (keyword) {
    T(keyword) + NT(:attribute_name) + Opt(T(:kLPAREN) + Opt(T(:tATIDENT)) + T(:kRPAREN)) + T(:kCOLON) + NT(:type)
  }

  grammar[:attr_reader].rule = attribute[:kATTRREADER]
  grammar[:attr_writer].rule = attribute[:kATTRWRITER]
  grammar[:attr_accessor].rule = attribute[:kATTRACCESSOR]

  mixin = -> (opr, only_interface:) {
    T(opr) + type_names[alias_name: false, module_name: !only_interface] + Opt(T(:kLBRACKET) + Repeat(NT(:type), T(:kCOMMA)) + T(:kRBRACKET))
  }

  grammar[:include].rule = mixin[:kINCLUDE, only_interface: false]
  grammar[:extend].rule = mixin[:kEXTEND, only_interface: false]
  grammar[:prepend].rule = mixin[:kPREPEND, only_interface: false]

  grammar[:include_interface].rule = mixin[:kINCLUDE, only_interface: true]
  grammar[:extend_interface].rule = mixin[:kEXTEND, only_interface: true]
  grammar[:prepend_interface].rule = mixin[:kPREPEND, only_interface: true]

  grammar[:module_members].rule = Opt(
    Repeat(
      Alt(
        NT(:module_decl),
        NT(:constant_decl),
        NT(:ivar_member),
        NT(:self_ivar_member),
        NT(:method_definition),
        NT(:alias_decl),
        NT(:type_alias_decl),
        NT(:include),
        NT(:extend),
        NT(:prepend),
        NT(:attr_reader),
        NT(:attr_writer),
        NT(:attr_accessor)
      )
    )
  )

  grammar[:use_wildcard_clause].rule = T(:kSTAR)
  grammar[:use_single_clause].rule =
    Alt(
      T(:tUIDENT) + Opt(T(:kAS) + T(:tUIDENT)),
      T(:tLIDENT) + Opt(T(:kAS) + T(:tLIDENT)),
      T(:tULIDENT)) + Opt(T(:kAS) + T(:tULIDENT)
    )
  grammar[:use_clause].rule = Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(NT(:use_wildcard_clause), NT(:use_single_clause))

  grammar[:use_directive].rule = T(:kUSE) + Repeat(NT(:use_clause), T(:kCOMMA))

  grammar[:start].rule =
    Opt(Repeat(NT(:use_directive))) +
      Repeat(
        Alt(
          NT(:module_decl),
          NT(:global_decl),
          NT(:type_alias_decl),
          NT(:constant_decl)
        )
      )
end

[tokenizer, grammar]
