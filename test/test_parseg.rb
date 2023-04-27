# frozen_string_literal: true

require "test_helper"

def empty_binding
  binding
end

class TestParseg < Minitest::Test
  include TreeAssertion

  rbs_file = File.join(__dir__, "../samples/rbs.rb")
  Tokenizer, Grammar = eval(File.read(rbs_file), empty_binding, rbs_file)

  def parse(source)
    parser = Parseg::Parser.new(grammar: Grammar, factory: Parseg::TokenFactory.new(tokenizer: Tokenizer, status: source))
    parser.error_tolerant_enabled = true
    parser.skip_unknown_tokens_enabled = true

    parser.parse(Grammar.non_terminals[:start])
  end

  def parse_changes(result, changes:)
    factory = result.factory.update(changes)

    deleted_tokens = factory.deleted_tokens
    if factory.inserted_tokens.empty? && !deleted_tokens.empty?
      end_id, _ = deleted_tokens.entries.last
      if range = result.tree_range_for_deleted_token(end_id)
        factory = result.factory.with_additional_change(range).update(changes)
      end
    end

    yield factory.source if block_given?

    parser = Parseg::Parser.new(grammar: Grammar, factory: factory)
    parser.error_tolerant_enabled = true
    parser.skip_unknown_tokens_enabled = true

    parser.parse(Grammar.non_terminals[:start])
  end

  def test_parsing_rbs_add
    session = Parseg::ParsingSession.new(grammar: Grammar, tokenizer: Tokenizer, start: :start)
    session.error_tolerant_enabled = true
    session.skip_unknown_tokens_enabled = true
    session.change_based_error_recovery_enabled = true

    result = session.update([[<<~RBS, [1, 0], [1, 0]]])
      module Foo

        alias foo bar
      end
    RBS

    assert_equal <<~RBS, session.last_source
      module Foo

        alias foo bar
      end
    RBS

    assert_tree(
      result.tree,
      {
        start: [
          {
            module_decl: [
              [:kMODULE, "module"],
              {
                module_name: [
                  [:tUIDENT, "Foo"]
                ]
              },
              {
                module_decl_rhs: [
                  {
                    module_members: [
                      {
                        alias_decl: [
                          [:kALIAS, "alias"],
                          {
                            method_name: [
                              [:tLIDENT, "foo"]
                            ]
                          },
                          {
                            method_name: [
                              [:tLIDENT, "bar"]
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  [:kEND, "end"]
                ]
              }
            ]
          }
        ]
      },
      factory: result.factory
    )

    result = session.update([
      ["  module Bar", [2, 0], [2, 0]]
    ])
    assert_equal <<~RBS, session.last_source
      module Foo
        module Bar
        alias foo bar
      end
    RBS

    assert_tree(
      result.tree,
      {
        start: [
          {
            module_decl: [
              [:kMODULE, "module"],
              {
                module_name: [
                  [:tUIDENT, "Foo"]
                ]
              },
              {
                module_decl_rhs: [
                  {
                    module_members: [
                      {
                        module_decl: [
                          [:kMODULE, "module"],
                          {
                            module_name: [
                              [:tUIDENT, "Bar"]
                            ]
                          },
                          {:unexpected=>:kALIAS}
                        ]
                      },
                      {
                        alias_decl: [
                          [:kALIAS, "alias"],
                          {
                            method_name: [
                              [:tLIDENT, "foo"]
                            ]
                          },
                          {
                            method_name: [
                              [:tLIDENT, "bar"]
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  [:kEND, "end"]
                ]
              }
            ]
          }
        ]
      },
      factory: result.factory
    )
  end

  def test_parsing_rbs_add2
    session = Parseg::ParsingSession.new(grammar: Grammar, tokenizer: Tokenizer, start: :start)
    session.error_tolerant_enabled = true
    session.skip_unknown_tokens_enabled = true
    session.change_based_error_recovery_enabled = true

    result = session.update([
      [<<~RBS, [1, 0], [1, 0]]
        module Foo
          module Bar

          end
          alias foo bar
        end
      RBS
    ])

    assert_tree(
      result.tree,
      {
        start: [
          {
            module_decl: [
              [:kMODULE, "module"],
              {
                module_name: [
                  [:tUIDENT, "Foo"]
                ]
              },
              {
                module_decl_rhs: [
                  {
                    module_members: [
                      {
                        module_decl: [
                          [:kMODULE, "module"],
                          {
                            module_name: [
                              [:tUIDENT, "Bar"]
                            ]
                          },
                          {
                            module_decl_rhs: [
                              {
                                module_members: []
                              },
                              [:kEND, "end"]
                            ]
                          }
                        ]
                      },
                      {
                        alias_decl: [
                          [:kALIAS, "alias"],
                          {
                            method_name: [
                              [:tLIDENT, "foo"]
                            ]
                          },
                          {
                            method_name: [
                              [:tLIDENT, "bar"]
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  [:kEND, "end"]
                ]
              }
            ]
          }
        ]
      },
      factory: result.factory
    )

    result = session.update(
      [
        ["    alias hello", [3, 0], [3, 0]]
      ]
    )

    assert_equal <<~RBS, session.last_source
      module Foo
        module Bar
          alias hello
        end
        alias foo bar
      end
    RBS

    assert_tree(
      result.tree,
      {
        start: [
          {
            module_decl: [
              [:kMODULE, "module"],
              {
                module_name: [
                  [:tUIDENT, "Foo"]
                ]
              },
              {
                module_decl_rhs: [
                  {
                    module_members: [
                      {
                        module_decl: [
                          [:kMODULE, "module"],
                          {
                            module_name: [
                              [:tUIDENT, "Bar"]
                            ]
                          },
                          {
                            module_decl_rhs: [
                              {
                                module_members: [
                                  {
                                    alias_decl: [
                                      [:kALIAS, "alias"],
                                      {
                                        method_name: [
                                          [:tLIDENT, "hello"]
                                        ]
                                      },
                                      { unexpected: :kEND }
                                    ]
                                  }
                                ]
                              },
                              [:kEND, "end"]
                            ]
                          }
                        ]
                      },
                      {
                        alias_decl: [
                          [:kALIAS, "alias"],
                          {
                            method_name: [
                              [:tLIDENT, "foo"]
                            ]
                          },
                          {
                            method_name: [
                              [:tLIDENT, "bar"]
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  [:kEND, "end"]
                ]
              }
            ]
          }
        ]
      },
      factory: result.factory
    )
  end

  def test_parsing_rbs_delete
    session = Parseg::ParsingSession.new(grammar: Grammar, tokenizer: Tokenizer, start: :start)
    session.error_tolerant_enabled = true
    session.skip_unknown_tokens_enabled = true
    session.change_based_error_recovery_enabled = true

    result = session.update([
      [<<~RBS, [1, 0], [1, 0]]
        module Foo
          module Bar
            module Baz
            end
          end

          alias foo bar
        end
      RBS
    ])

    assert_tree(
      result.tree,
      {
        start: [
          {
            module_decl: [
              [:kMODULE, "module"],
              {
                module_name: [
                  [:tUIDENT, "Foo"]
                ]
              },
              {
                module_decl_rhs: [
                  {
                    module_members: [
                      {
                        module_decl: [
                          [:kMODULE, "module"],
                          {
                            module_name: [
                              [:tUIDENT, "Bar"]
                            ]
                          },
                          {
                            module_decl_rhs: [
                              {
                                module_members: [
                                  {
                                    module_decl: [
                                      [:kMODULE, "module"],
                                      {
                                        module_name: [
                                          [:tUIDENT, "Baz"]
                                        ]
                                      },
                                      {
                                        module_decl_rhs: [
                                          {
                                            module_members: []
                                          },
                                          [:kEND, "end"]
                                        ]
                                      }
                                    ]
                                  }
                                ]
                              },
                              [:kEND, "end"]
                            ]
                          }
                        ]
                      },
                      {
                        alias_decl: [
                          [:kALIAS, "alias"],
                          {
                            method_name: [
                              [:tLIDENT, "foo"]
                            ]
                          },
                          {
                            method_name: [
                              [:tLIDENT, "bar"]
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  [:kEND, "end"]
                ]
              }
            ]
          }
        ]
      },
      factory: result.factory
    )

    result = session.update(
      [
        [
          "",
          [4, 0],
          [6, 0]
        ]
      ]
    )

    assert_equal <<~RBS, session.last_source
      module Foo
        module Bar
          module Baz

        alias foo bar
      end
    RBS

    assert_tree(
      result.tree,
      {
        start: [
          {
            module_decl: [
              [:kMODULE, "module"],
              {
                module_name: [
                  [:tUIDENT, "Foo"]
                ]
              },
              {
                module_decl_rhs: [
                  {
                    module_members: [
                      {
                        module_decl: [
                          [:kMODULE, "module"],
                          {
                            module_name: [
                              [:tUIDENT, "Bar"]
                            ]
                          },
                          {
                            module_decl_rhs: [
                              {
                                module_members: [
                                  {
                                    module_decl: [
                                      [:kMODULE, "module"],
                                      {
                                        module_name: [
                                          [:tUIDENT, "Baz"]
                                        ]
                                      },
                                      {:unexpected=>:kALIAS}
                                    ]
                                  }
                                ]
                              },
                              {:unexpected=>:kALIAS}
                            ]
                          }
                        ]
                      },
                      {
                        alias_decl: [
                          [:kALIAS, "alias"],
                          {
                            method_name: [
                              [:tLIDENT, "foo"]
                            ]
                          },
                          {
                            method_name: [
                              [:tLIDENT, "bar"]
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  [:kEND, "end"]
                ]
              }
            ]
          }
        ]
      },
      factory: result.factory
    )
  end
end
