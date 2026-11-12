# frozen_string_literal: true

module GenieSpecSupport
  # The JavaScript sources the js specs need, without committing third-party code (lich-5
  # is BSD-3-Clause; the GPLv3 js_arrays.js versions, SkillData.cmd's block and ubercombat's
  # TEXT_TO_NUMBER block stay in the lab).
  #
  #   * {synthetic_library}: a stand-in js_arrays.js -- one synthetic declaration per function of
  #     a version, each registered (by its real {Lich::Genie::JsSource} fingerprint) with that
  #     version's replay -- so specs exercise split -> fingerprint -> replay end to end;
  #   * {lab_path} / {lab_source}: the real files from the lab's flow-oracle tests dir
  #     (~/genie-port-lab/flow-oracle/tests; GENIE_LAB_FLOW_TESTS overrides it), for the
  #     examples that pin the stored fingerprints; they skip when it is absent.
  module JsLibrary
    LAB_DIR = ENV.fetch('GENIE_LAB_FLOW_TESTS', File.expand_path('~/genie-port-lab/flow-oracle/tests'))

    # The real js_arrays.js file of each version in the lab dir.
    LAB_FILES = {
      b249849: '_js_arrays_b249849.js', '0ad2095': '_js_arrays_0ad2095.js', '1bfe9a2': '_js_arrays_1bfe9a2.js',
      '9a9462a': '_js_arrays_9a9462a.js', a7f2496: '_js_arrays_miner.js', c878a96: '_js_arrays_c878a96.js',
      '5e08eba': 'js_arrays.js'
    }.transform_keys(&:to_sym).freeze

    module_function

    # @param name [String] a file of the lab's flow-oracle tests dir
    # @return [String, nil] its path, nil when the lab is not here
    def lab_path(name)
      path = File.join(LAB_DIR, name)
      File.file?(path) ? path : nil
    end

    # The block RunJsblock executes for a `.js` include: its TrimStart()ed non-blank rows, each
    # followed by a line break.
    # @param path [String]
    # @return [String]
    def include_source(path)
      text = File.binread(path)
      Lich::Genie::Lexer.split_lines(text).map { |l| Lich::Genie::Text.net_trim_start(l) }.reject(&:empty?)
                        .map { |row| "#{row}\n" }.join
    end

    # @param name [String]
    # @return [String] the message an example skips with when the lab file is absent
    def lab_missing(name)
      "lab-only source #{name} (third-party, not in the repo) is not in #{LAB_DIR}"
    end

    # A synthetic js_arrays.js for +copy+ and the FUNCTION_BODIES table that recognises it.
    # @param copy [Symbol] a JsArrays::COPIES key
    # @return [Array(String, Hash)] the include text and the table to stub_const
    def synthetic_library(copy)
      bodies = {}
      text = Lich::Genie::JsArrays.functions_of(copy).map do |name, callable|
        declaration = "function #{name}(a, b, c) {\n  // synthetic stand-in for the #{copy} body\n}\n"
        bodies[Lich::Genie::JsSource.fingerprint(declaration)] = Lich::Genie::JsArrays::Body.new(name, callable, [copy])
        declaration
      end.join
      [text, bodies.freeze]
    end
  end
end
