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

keywords = %w(
  void
  untyped
  nil
  self
  class
  module
  singleton
  bool
  def
  interface
  unchecked
  include
  extend
  prepend
  in
  out
  alias
  type
  use
  as
  attr_reader
  attr_accessor
  attr_writer
  true
  false
  end
).each.with_object({}) do |word, kwds|
  kwds[:"k#{word.upcase.gsub('_', '')}"] = /#{Regexp.quote(word)}\b/
end

tokenizer = define_tokenizer(
  kSELFQ: /self\?/,
  kSELFBANG: /self!/,
  kSELFEQ: /self=/,
  **keywords,
  kLPAREN: /\(/,
  kRPAREN: /\)/,
  kCOLON2: /::/,
  tNAMESPACE: /([A-Z]\w*::)+/,
  tSYMBOL: /:\w+/,
  kCOLON: /:/,
  kARROW: /\-\>/,
  kOPERATOR: Regexp.union(%w(+@ + -@ - != !~ ! []= [] / % ` ^ <=> << <= === == =~ >= >> > ~)),
  kBAR: /\|/,
  kAND: /\&/,
  kLT: /\</,
  kEQ: /\=/,
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

  tUKEYWORD: /[A-Z]\w*[!?=]?:/,
  tUIDENT_BANG: /[A-Z]\w*!/,
  tUIDENT_EQ: /[A-Z]\w*=/,
  tUIDENT_Q: /[A-Z]\w*\?/,
  tUIDENT: /[A-Z]\w*/,

  tLKEYWORD: /[a-z]\w*[!?=]?:/,
  tLIDENT_BANG: /[a-z]\w*!/,
  tLIDENT_EQ: /[a-z]\w*=/,
  tLIDENT_Q: /[a-z]\w*\?/,
  tLIDENT: /[a-z]\w*/,

  tULKEYWORD: /_\w*[!?=]?:/,
  tULIDENT_BANG: /_\w*!/,
  tULIDENT_EQ: /_\w*=/,
  tULIDENT_Q: /_\w*\?/,
  tULIDENT: /_\w*/,

  tATIDENT: /@\w+/,
  tGIDENT: /\$[a-zA-Z]\w*/,

  tDQSTRING: /"([^\\]|\\")*"/,
  tSQSTRING: /'([^\\]|\\')*'/,

  tINTEGER: /\d+/,

)

grammar = Parseg::Grammar.new() do |grammar|
  grammar[:type].rule = Alt(
    NT(:base_type),
    NT(:type_name) + Opt(
      T(:kLBRACKET) + Repeat(NT(:type), T(:kCOMMA)) + T(:kRBRACKET)
    ) + Opt(T(:kQUESTION))
  )

  grammar[:type_name].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tLIDENT), T(:tULIDENT))

  grammar[:base_type].rule = Alt(
    T(:kVOID), T(:kUNTYPED), T(:kNIL), T(:kSELF), T(:kBOOL)
  )

  grammar[:method_type].rule = Opt(NT(:type_params)) + Opt(NT(:params)) + T(:kARROW) + NT(:type)

  grammar[:type_params].rule =
    T(:kLBRACKET) + Repeat(NT(:type_param), T(:kCOMMA)) + T(:kRBRACKET)

  grammar[:type_param].rule =
    Opt(T(:kUNCHECKED)) + Opt(Alt(T(:kIN), T(:kOUT))) + T(:tUIDENT) + Opt(T(:kLT) + NT(:upper_bound))

  grammar[:upper_bound].rule =
    NT(:upper_bound_name) + Opt(NT(:type_args))

  grammar[:upper_bound_name].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(T(:tUIDENT), T(:tULIDENT))

  grammar[:params].rule = T(:kLPAREN) + Opt(Repeat(NT(:type), T(:kCOMMA))) + T(:kRPAREN)

  grammar[:module_name].rule =
    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + T(:tUIDENT)

  type_names = -> (module_name: true, interface_name: true, alias_name: true) {
    list = []

    list << T(:tUIDENT) if module_name
    list << T(:tLIDENT) if alias_name
    list << T(:tULIDENT) if interface_name

    Opt(T(:kCOLON2)) + Opt(T(:tNAMESPACE)) + Alt(*list)
  }

  grammar[:interface_name].rule = type_names[module_name: false, alias_name: false]

  grammar[:module_decl].block!.rule =
    T(:kMODULE) + NT(:module_name) +
      Opt(NT(:type_params)) +
      Opt(T(:kCOLON) + NT(:module_self_decl)) +
      NT(:module_members) +
      T(:kEND)

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
    T(:kDEF) + NT(:method_name_colon) + NT(:method_types)

  grammar[:method_name_colon].rule =
    Alt(
      NT(:self_method_name_colon),
      NT(:raw_method_name_colon),
    )

  grammar[:self_method_name_colon].rule =
    Alt(T(:kSELF), T(:kSELFQ)) + Alt(
      T(:kCOLON),
      T(:kDOT) + Alt(
        NT(:raw_method_name_colon),
        T(:kSELF) + T(:kCOLON),
        T(:kSELFQ) + T(:kCOLON)
      )
    )

  grammar[:raw_method_name_colon].rule =
    Alt(
      NT(:method_name_ident) + T(:kCOLON),
      Alt(T(:kSELFEQ), T(:kSELFBANG)) + T(:kCOLON),
      T(:tLKEYWORD),
      T(:tUKEYWORD),
      T(:tULKEYWORD)
    )

  grammar[:method_name_ident].rule =
    Alt(
      T(:tLIDENT),
      T(:tLIDENT_BANG),
      T(:tLIDENT_EQ),
      T(:tLIDENT_Q),
      T(:tUIDENT),
      T(:tUIDENT_BANG),
      T(:tUIDENT_EQ),
      T(:tUIDENT_Q),
      T(:tULIDENT),
      T(:tULIDENT_BANG),
      T(:tULIDENT_EQ),
      T(:tULIDENT_Q),
      T(:kVOID),
      T(:kUNTYPED),
      T(:kNIL),
      T(:kSELFBANG),
      T(:kSELFEQ),
      T(:kCLASS),
      T(:kMODULE),
      T(:kSINGLETON),
      T(:kBOOL),
      T(:kDEF),
      T(:kINTERFACE),
      T(:kUNCHECKED),
      T(:kIN),
      T(:kOUT),
      T(:kINCLUDE),
      T(:kEXTEND),
      T(:kPREPEND),
      T(:kALIAS),
      T(:kTYPE),
      T(:kUSE),
      T(:kAS),
      T(:kATTRREADER),
      T(:kATTRACCESSOR),
      T(:kATTRWRITER),
      T(:kTRUE),
      T(:kFALSE),
      T(:kEND),
      T(:kOPERATOR),
      T(:kLT),
      T(:kAND),
      T(:kBAR),
      T(:kSTAR),
      T(:kSTAR2),
    )

  grammar[:instance_method_definition].rule =
    T(:kDEF) + NT(:raw_method_name_colon) + NT(:method_types)

  grammar[:method_types].rule =
    Alt(
      T(:kDOT3),
      NT(:method_type) + Opt(T(:kBAR) + NT(:method_types))
    )

  grammar[:alias_decl].rule =
    T(:kALIAS) + NT(:alias_name_decl) + NT(:alias_name_decl)

  grammar[:alias_name_decl].rule = Alt(NT(:self_alias_name), NT(:alias_name_ident))

  grammar[:alias_name_ident].rule = Alt(NT(:method_name_ident), Alt(T(:kSELFQ)))

  grammar[:self_alias_name].rule =
    T(:kSELF) + Opt(T(:kDOT) + Alt(T(:kSELF), NT(:alias_name_ident)))

  grammar[:type_alias_decl].rule =
    T(:kTYPE) + type_names[module_name: false, interface_name: false] + Opt(NT(:type_params)) + T(:kEQ) + NT(:type)

  grammar[:global_decl].rule =
    T(:tGIDENT) + T(:kCOLON) + NT(:simple_type)

  grammar[:attribute_name_decl].rule =
    Alt(
      T(:tLIDENT) + T(:kCOLON),
      T(:tLKEYWORD),
    )

  attribute = -> (keyword) {
    T(keyword) + NT(:attribute_name_decl) + NT(:type)
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
        NT(:class_decl),
        NT(:interface_decl),
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

  grammar[:interface_decl].block!.rule = T(:kINTERFACE) + NT(:interface_name) + Opt(NT(:type_params)) + NT(:interface_members) + T(:kEND)

  grammar[:interface_members].rule = Opt(
    Repeat(
      Alt(
        NT(:instance_method_definition),
        NT(:include_interface)
      )
    )
  )

  grammar[:class_decl].block!.rule =
    T(:kCLASS) + NT(:module_name) +
      Opt(NT(:type_params)) +
      Opt(NT(:class_decl_super)) +
      NT(:class_members) +
      T(:kEND)

  grammar[:class_decl_super].rule = T(:kLT) + NT(:module_name) + Opt(NT(:type_args))

  grammar[:class_members].rule =
    Opt(
      Repeat(
        Alt(
          NT(:module_decl),
          NT(:class_decl),
          NT(:interface_decl),
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

  grammar[:type_args].rule = T(:kLBRACKET) + Repeat(NT(:type), T(:kCOMMA)) + T(:kRBRACKET)

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
      Opt(
        Repeat(
          Alt(
            NT(:class_decl),
            NT(:module_decl),
            NT(:interface_decl),
            NT(:global_decl),
            NT(:type_alias_decl),
            NT(:constant_decl)
          )
        )
      )
end

[tokenizer, grammar]
