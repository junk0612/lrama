# frozen_string_literal: true

RSpec.describe Lrama::Tracer::Rules do
  describe "#trace" do
    let(:path) { "common/basic.y" }
    let(:y) { File.read(fixture_path(path)) }
    let(:grammar) do
      grammar = Lrama::Parser.new(y, path).parse
      grammar.prepare
      grammar.validate!
      grammar
    end

    context "when rules: true and only_explicit: false" do
      it "prints the all rules" do
        expect do
          described_class.new(STDERR, rules: true, only_explicit: false).trace(grammar)
        end.to output(<<~RULES).to_stderr_from_any_process
          Grammar rules:
          $accept -> program EOI
          program -> class
          program -> '+' strings_1
          program -> '-' strings_2
          class -> keyword_class tSTRING keyword_end
          $@1 -> ε
          $@2 -> ε
          class -> keyword_class $@1 tSTRING '!' keyword_end $@2
          $@3 -> ε
          $@4 -> ε
          class -> keyword_class $@3 tSTRING '?' keyword_end $@4
          strings_1 -> string_1
          strings_2 -> string_1
          strings_2 -> string_2
          string_1 -> string
          string_2 -> string '+'
          string -> tSTRING
          unused -> tNUMBER
        RULES
      end
    end

    context "when rules: true and only_explicit: true" do
      it 'does not print anything' do
        expect do
          described_class.new(STDERR, rules: true, only_explicit: true).trace(grammar)
        end.to_not output.to_stderr_from_any_process
      end
    end

    context "when rules: false" do
      it 'does not print anything' do
        expect do
          described_class.new(STDERR, rules: false).trace(grammar)
        end.to_not output.to_stderr_from_any_process
      end
    end

    context 'when empty options' do
      it 'does not print anything' do
        expect do
          described_class.new(STDERR).trace(grammar)
        end.to_not output.to_stderr_from_any_process
      end
    end
  end
end
