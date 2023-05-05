D = Steep::Diagnostic

target :lib do
  signature "sig"
  check "lib", "exe/parseg-lsp", "samples/*.rb"

  # configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
  # configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
  configure_code_diagnostics do |hash|             # You can setup everything yourself
    hash[D::Ruby::MethodDefinitionMissing] = :hint
  end
end

# target :test do
#   signature "sig", "sig-private"
#
#   check "test"
#
#   # library "pathname", "set"       # Standard libraries
# end
