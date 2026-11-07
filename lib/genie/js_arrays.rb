# frozen_string_literal: true

module Lich
  module Genie
    # What Remix's Jint 4 engine does with the JavaScript of the corpus (decided:
    # fail like Remix), replayed step by step -- every getVar/getGlobal/setVar in order, the
    # globals it leaves, and the exception Jint throws.
    #
    # The community js_arrays.js (DR-Genie-Scripts JS_Arrays/, Miner/, mm_train/; GPLv3) has been
    # published in seven versions since 2019, and players bring their own copy. Each is recognised
    # FUNCTION BY FUNCTION ({FUNCTION_BODIES}, keyed by {JsSource} fingerprints of the declaration
    # text, comments and layout aside): a known body runs as Jint runs it, a body this
    # port does not know is defined but unsupported when called. Every version calls
    # `list.length()` -- `length` is a property, so Jint 4 throws TypeError "Property 'length' of
    # object is not a function" as soon as such a call is reached (genieflow probes): 15 of
    # the functions always throw, and doSort does for the orders 0 and 1; a `jscall` then stores
    # "undefined" after Remix's "[Script error ...]" line. Only doPush, doUnshift, doConcat,
    # doReplace, buildArray and doSort with any other order run to the end. The versions differ in
    # how doPush / doUnshift / findIndex / checkExists / doXCompare / buildArrayStr resolve a
    # `%name` / `$name` argument ({resolve}), in what doPush treats as an empty array, in
    # buildArray's " and some " and in which functions exist (zipArrays and doReplace only since
    # 2024 / 2025).
    #
    # Two `<% %>` blocks of the corpus are recognised whole ({SOURCES}, by the {JsSource}
    # fingerprint of the block Remix executes, so trailing spaces, indentation and comments aside):
    # SkillData.cmd's sort and ubercombat's TEXT_TO_NUMBER.
    #
    # Not modelled (0 corpus uses): the message of an invalid buildArrayStr pattern (Jint's regex
    # parser has its own texts and validity rules; this reports "Invalid regular expression:
    # /<pattern>/i" for what Ruby rejects), and arrays grown past {MAX_LENGTH} elements.
    module JsArrays
      LENGTH_FAULT = "Property 'length' of object is not a function"

      # Larger arrays (doReplace("a", "4000000000", ..)) are not built here.
      MAX_LENGTH = 10_000_000

      # A recognised `<% %>` block: the functions it declares, the globals it assigns before
      # running anything (opaque values), and what running it does.
      Source = Struct.new(:name, :functions, :effect, :globals) do
        # @param runtime [JsRuntime]
        def run(runtime)
          runtime.define(functions) if functions
          globals&.each { |global| runtime.assign(global, JsRuntime::OPAQUE) }
          effect&.call(runtime)
        end
      end

      # A recognised function declaration: its name, what calling it does
      # (callable.call(runtime, args)) and the js_arrays.js versions that declare it.
      Body = Struct.new(:name, :callable, :copies)

      module_function

      # --- the js_arrays.js functions (args are JS values, missing ones undefined) -----------

      # A `%name` / `$name` argument, as each version resolves it:
      #   :else_if      `if (x[0] == "%") x = getVar(..) else if (x[0] == "$") x = getGlobal(..)`
      #   :sequential   the same with `if` for `else if`: a %name whose value starts with "$" reads
      #                 that global too (findIndex until 2022, doPush / doUnshift 2019-02 to 2022)
      #   :percent_only no `$` branch (the 2019-01 copies; checkExists, doXCompare and
      #                 buildArrayStr until 2022)
      # +strip_dollar+: `getGlobal(x.replace("$", ""))` (the search functions) or
      # `getGlobal(x.replace(/$/, ""))` -- which matches the END of the string, so a `$name` item
      # reads the global "$name" (never set: "") (doPush / doUnshift).
      def resolve(runtime, value, mode, strip_dollar:)
        first = JsValue.index0(value)
        if first == '%'
          value = runtime.get_var(value.sub('%', ''))
          return value unless mode == :sequential

          first = JsValue.index0(value)
        end
        return value unless first == '$' && mode != :percent_only

        runtime.get_global(strip_dollar ? value.sub('$', '') : value)
      end

      # doSort(arrayname, sorting): `switch(sorting)` is strict, so only the NUMBERS 0 and 1 reach
      # the throwing loops; any other order writes the array back unchanged.
      def do_sort(runtime, (name, sorting))
        list = JsValue.split_bar(runtime.get_var(name))
        if sorting.is_a?(Float) && [0.0, 1.0].include?(sorting)
          runtime.assign('i', 0.0)
          raise JsRuntime::JsError, LENGTH_FAULT
        end
        runtime.set_var(name, JsValue.join_bar(list))
      end

      # findIndex / checkExists / doXCompare (+target: the second array it reads first).
      def find_index(runtime, (name, srch, *), mode:)
        runtime.get_var(name)
        find_index_loop(runtime, srch, mode)
      end

      def do_x_compare(runtime, (source, target, srch), mode:)
        runtime.get_var(source)
        runtime.get_var(target)
        find_index_loop(runtime, srch, mode)
      end

      def find_index_loop(runtime, srch, mode)
        resolve(runtime, srch, mode, strip_dollar: true)
        runtime.assign('i', 0.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # doRemove: `var index = findIndex(arrayname, srch);` -- whatever findIndex the engine holds
      # now (every known one throws; an unknown one is unsupported; none: ReferenceError).
      def do_remove(runtime, (name, srch, *))
        runtime.call_function('findIndex', [name, srch])
        raise JsRuntime::Unsupported, 'doRemove after a findIndex that returned'
      end

      def do_insert(runtime, (name, items, _position))
        runtime.get_var(name)
        JsValue.call_to_string(items)
        runtime.assign('i', 0.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # doReplace(arrayname, position, item): `list[position] = item` -- an array index (a
      # canonical uint32 below 2**32-1) sets that element (padding with holes), `length`
      # truncates or pads (RangeError, empty message, when not a uint32), any other key is a plain
      # property join() never shows. The first 2025 copy does not resolve `%name` arguments.
      def do_replace(runtime, (name, position, item), resolve_names:)
        list = JsValue.split_bar(runtime.get_var(name))
        if resolve_names
          item = runtime.get_var(item.sub('%', '')) if JsValue.index0(item) == '%'
          position = runtime.get_var(position.sub('%', '')) if JsValue.index0(position) == '%'
        end
        assign_element(list, JsValue.to_string(position), item)
        runtime.set_var(name, JsValue.join_bar(list))
      end

      def assign_element(list, key, item)
        if key == 'length'
          size = JsValue.to_number(item) # ArraySetLength: ToUint32(size) must equal size
          raise JsRuntime::JsError, '' unless size.finite? && size.modulo(1).zero? && size.between?(0, (2**32) - 1)

          resize(list, size.to_i)
        elsif key.match?(/\A(?:0|[1-9][0-9]*)\z/) && key.to_i < (2**32) - 1
          resize(list, key.to_i + 1) if key.to_i >= list.length
          list[key.to_i] = item
        end
      end

      def resize(list, length)
        raise JsRuntime::Unsupported, "an array of #{length} elements" if length > MAX_LENGTH

        length < list.length ? list.slice!(length..) : list.concat([nil] * (length - list.length))
      end

      def do_concat(runtime, (name, array))
        list = JsValue.split_bar(runtime.get_var(name))
        more = JsValue.split_bar(JsValue.call_to_string(array))
        runtime.set_var(name, JsValue.join_bar(list + more))
      end

      # doPush: the first element is replaced when it is one of +empties+ ("undefined", and ""
      # since 2024), else the item is appended.
      def do_push(runtime, (name, item), mode:, empties:)
        list = JsValue.split_bar(runtime.get_var(name))
        item = resolve(runtime, item, mode, strip_dollar: false)
        if empties.include?(list[0]) then list[0] = item
        else list.push(item)
        end
        runtime.set_var(name, JsValue.join_bar(list))
      end

      # doUnshift: only an "undefined" first element is replaced (an empty array gains a "").
      def do_unshift(runtime, (name, item), mode:)
        list = JsValue.split_bar(runtime.get_var(name))
        item = resolve(runtime, item, mode, strip_dollar: false)
        if list[0] == 'undefined' then list[0] = item
        else list.unshift(item)
        end
        runtime.set_var(name, JsValue.join_bar(list))
      end

      # doPop / doShift: `if (list.length() > 0)`.
      def do_pop(runtime, (name))
        runtime.get_var(name)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # buildArray: " and some " joins too since 2019-02.
      def build_array(runtime, (name, raw), and_pattern:)
        runtime.set_var(name, prose(JsValue.call_to_string(raw), and_pattern))
      end

      # buildArrayStr: the `$` branch (2024 on) reads `srch`, a typo: ReferenceError.
      def build_array_str(runtime, (_name, raw, pattern), mode:)
        JsValue.split_bar(prose(JsValue.call_to_string(raw), / and (a|an) /))
        case JsValue.index0(pattern)
        when '%' then pattern = runtime.get_var(pattern.sub('%', ''))
        when '$' then raise JsRuntime::JsError, 'srch is not defined' if mode == :else_if
        end
        check_pattern(JsValue.to_string(pattern))
        runtime.assign('i', 0.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # `.replace(/, /g, "|").replace(and, "|").replace(/\ban? /g, "")`; JS \b is ASCII-only.
      def prose(text, and_pattern)
        text.gsub(', ', '|').sub(and_pattern, '|').gsub(/(?<![A-Za-z0-9_])an? /, '')
      end

      # Too deep for Onigmo is valid for Jint (genieflow: 1,500 and 5,000 levels), so it is not
      # compiled (NetRegex::MAX_GROUP_DEPTH).
      def check_pattern(source)
        return if NetRegex.too_deep?(source)

        Regexp.new(source)
      rescue RegexpError
        raise JsRuntime::JsError, "Invalid regular expression: /#{source}/i"
      end

      # findMax / findMin / findMaxIndex / findMinIndex: `for(i = 1; i < list.length(); ...)`.
      def find_extreme(runtime, (name))
        runtime.get_var(name)
        runtime.assign('i', 1.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # findMaxGlobal / findMinGlobal: `for(i = 0; i < list.length(); ...)`.
      def find_extreme_global(runtime, (name))
        runtime.get_var(name)
        runtime.assign('i', 0.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # zipArrays: `for(j = 0; j < tozip.length(); ...)`.
      def zip_arrays(runtime, (first, second))
        runtime.get_var(first)
        runtime.get_var(second)
        runtime.assign('j', 0.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # --- the recognised `<% %>` blocks --------------------------------------------------------

      # SkillData.cmd's `<% %>` sort: `list = getVar('skills').toString(); list = list.split("|");
      # for(i = 0; i < list.length() - 1; i++)`.
      def skilldata_sort(runtime)
        runtime.get_var('skills')
        runtime.assign('list', JsRuntime::OPAQUE)
        runtime.assign('i', 0.0)
        raise JsRuntime::JsError, LENGTH_FAULT
      end

      # ubercombat TEXT_TO_NUMBER (uber.cmd, called from AMMO_SET with a count in words):
      # `var map = {'zero': 0, .. 'ninety': 90}; var magnitude_map = {'thousand': 1000, ..
      # 'decillion': 1e33}; function textToNumber() {..} textToNumber();`.
      TEXT_NUMBERS = (%w[zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen
                         seventeen eighteen nineteen].each_with_index.map { |word, i| [word, i.to_f] } +
                      %w[twenty thirty forty fifty sixty seventy eighty ninety].each_with_index.map { |word, i| [word, (i + 2) * 10.0] })
                     .to_h.freeze
      MAGNITUDES = %w[thousand million billion trillion quadrillion quintillion sextillion septillion octillion nonillion
                      decillion].each_with_index.to_h { |word, i| [word, Float("1e#{(i + 1) * 3}")] }.freeze
      # `map[word]` / `magnitude_map[word]` find these on Object.prototype (a function or object,
      # not undefined): Jint then concatenates its source text ("0function Object() { [native
      # code] }0", a genieflow probe) -- not modelled.
      OBJECT_PROTOTYPE_KEYS = %w[constructor __proto__ __defineGetter__ __defineSetter__ __lookupGetter__ __lookupSetter__
                                 hasOwnProperty isPrototypeOf propertyIsEnumerable toLocaleString toString valueOf].freeze
      # `split(/[\s-]+/)`: JS \s is WhiteSpace + LineTerminator.
      WORD_SEPARATOR = Regexp.new("[#{Regexp.escape(JsValue::WHITESPACE)}-]+")

      def text_to_number(runtime, _args = [])
        text = runtime.get_var('number_as_string')
        number = 0.0
        scale = 0.0
        (text.empty? ? [''] : text.split(WORD_SEPARATOR, -1)).each do |part|
          raise JsRuntime::Unsupported, "textToNumber of #{part.inspect} (an Object.prototype key)" if OBJECT_PROTOTYPE_KEYS.include?(part)

          if TEXT_NUMBERS.key?(part) then number += TEXT_NUMBERS[part]
          elsif part == 'hundred' then number *= 100
          else
            magnitude = MAGNITUDES[part]
            runtime.assign('magnitude', magnitude) # undeclared: a global, undefined when not found
            next unless magnitude

            scale += number * magnitude
            number = 0.0
          end
        end
        runtime.set_var('text_to_number', number + scale)
      end

      # @return [#call] a body's callable: +method+ with +options+ bound
      def bound(name, **options)
        callable = method(name)
        options.empty? ? callable : ->(runtime, args) { callable.call(runtime, args, **options) }
      end
      private_class_method :bound

      # The js_arrays.js versions (DR-Genie-Scripts blob, commit, date, lines).
      COPIES = {
        b249849: 'JS_Arrays/js_arrays.js e5d201e 2019-01-29 (410 lines)',
        '0ad2095': 'Miner/ and mm_train/js_arrays.js a7b664c / bf7ee54 2019-01-29 (405 lines)',
        '1bfe9a2': 'JS_Arrays/js_arrays.js 2ee1501 2019-02-17 (419 lines)',
        '9a9462a': 'JS_Arrays/js_arrays.js aa93b3a 2022-03-30 (419 lines)',
        a7f2496: 'JS_Arrays/, Miner/ and mm_train/js_arrays.js a15931c / 6ff6970 / 870e564 2024-04-11 (457 lines; ' \
                 'Miner/ and mm_train/ today)',
        c878a96: 'JS_Arrays/js_arrays.js 5c161d9 2025-08-31 (471 lines)',
        '5e08eba': 'JS_Arrays/js_arrays.js e9794af 2025-08-31 (480 lines; JS_Arrays/ today)'
      }.transform_keys(&:to_sym).freeze

      ALL = COPIES.keys.freeze
      SINCE_2024 = %i[a7f2496 c878a96 5e08eba].freeze
      UNTIL_2022 = %i[b249849 0ad2095 1bfe9a2 9a9462a].freeze
      PUSH_EMPTIES = %w[undefined].freeze
      PUSH_EMPTIES_2024 = ['undefined', ''].freeze

      # The function declarations of every js_arrays.js version, by {JsSource} fingerprint.
      FUNCTION_BODIES = [
        ['doSort', '75c45c0c484859a58aaac1a657be1325360f89c172229c18830ce17b6138b26b', %i[b249849 1bfe9a2], bound(:do_sort)],
        ['doSort', '84a22c5fe24f5c7eaec4ffe3a408f97e56992c4e6a2075164c8e3d9ec7bdc361', %i[0ad2095], bound(:do_sort)],
        ['doSort', 'b0c67d26b5326051406f4a9389078864f77f72ef577a82921826f6491f1ee8fe', %i[9a9462a] + SINCE_2024, bound(:do_sort)],
        ['findIndex', 'e7aa658ad38787e1df3b3b4edfbfdc55bde119c9b000caef53ee9b42b77fdb55', %i[0ad2095],
         bound(:find_index, mode: :percent_only)],
        ['findIndex', '1224576460d5547d1e182a2cb4c57075e13879868eb6b6cedd21da192090c91e', %i[b249849 1bfe9a2 9a9462a],
         bound(:find_index, mode: :sequential)],
        ['findIndex', '224e55ff9c3e46ac6440987bffb34a4748e2f023506b41592d36857421466404', SINCE_2024, bound(:find_index, mode: :else_if)],
        ['checkExists', 'bc2bc5c43d0dc2b05ed1ebb225288c92e560246afdf6f85b890b94ffac3fa601', UNTIL_2022,
         bound(:find_index, mode: :percent_only)],
        ['checkExists', 'cece85427d3fef36b933e783220a15c7707bd2ef2e628fdf25c157641f0d5f2d', %i[a7f2496], bound(:find_index, mode: :else_if)],
        # (with two echo lines in the loop, never reached)
        ['checkExists', 'f4dadeab835e242f1fe2124b7cf73d43a9b2c2051dbcf172cde2647ec35eef00', %i[c878a96 5e08eba],
         bound(:find_index, mode: :else_if)],
        ['doInsert', '5b3fe2bf2b84fcee2c40b67deff6d0f347982df8c0524cfd0eb8a484a6210a6a', ALL, bound(:do_insert)],
        ['doRemove', '9080d423ab60470078cd7cd868028e8d716df0c89c4b22470587937fd0d9bb52', UNTIL_2022, bound(:do_remove)],
        ['doRemove', '0a97e087bbb3fe5a46a8c2a8e8f36a309d2b8dbb5d7a9df8b34208b31b087499', SINCE_2024, bound(:do_remove)],
        ['doReplace', 'cbbdbc0c5ad7715ac8c2020373ac2e81d93897ade7aaeafc89db6df54d656491', %i[c878a96],
         bound(:do_replace, resolve_names: false)],
        ['doReplace', '5cd609e64d5f52a87eb60047bc8c74bc494e0a5f6d239520b7ad1724ce5b457a', %i[5e08eba],
         bound(:do_replace, resolve_names: true)],
        ['doConcat', '33ff718cfc3b6afa7036a8d4aca69b5d053a2a14931869dd2db2ac4e96e4cf46', ALL, bound(:do_concat)],
        ['doXCompare', '11b7d933db4407b2cb8415cc4db29f0d99a3de512709324261528f6cacfba0d0', UNTIL_2022,
         bound(:do_x_compare, mode: :percent_only)],
        ['doXCompare', '3949c90ed90b24a97003d8499609ebbbe47b9fb6cf3ce6ee8da38edd9a356a34', SINCE_2024,
         bound(:do_x_compare, mode: :else_if)],
        ['doPush', '26fe9cbd6d91a0dcd54bd59569db72335a590b8cd528c0008a486a3dfe2d795d', %i[b249849 0ad2095],
         bound(:do_push, mode: :percent_only, empties: PUSH_EMPTIES)],
        ['doPush', '5025c9800640b9e4e5f36959875a825b2e90bff47f18eb4019568b83a17cbfb9', %i[1bfe9a2 9a9462a],
         bound(:do_push, mode: :sequential, empties: PUSH_EMPTIES)],
        ['doPush', '8aa9d63e3df0351bbed83ed6c4bebfbb8b8bce300814dfc22630802bbcca126a', SINCE_2024,
         bound(:do_push, mode: :else_if, empties: PUSH_EMPTIES_2024)],
        ['doPop', 'c9de370be44a565a76b4bd48577ee7e2b44eea78f74c709fc4beb9cf5dc992dc', ALL, bound(:do_pop)],
        ['doUnshift', 'e7310edf185b3cc16d2dbabc99dc30558432f1149176ab42a1661175cebc7531', %i[b249849 0ad2095],
         bound(:do_unshift, mode: :percent_only)],
        ['doUnshift', '4c5419674fc02ba4c03a64b407ee8f9b3eb7ce002578d285c48fcd2fcfa9f7be', %i[1bfe9a2 9a9462a],
         bound(:do_unshift, mode: :sequential)],
        ['doUnshift', '006416f665b30a21bed5f57a55211aa2d8f659fb04b1ed9044a8fde170b47dc9', SINCE_2024, bound(:do_unshift, mode: :else_if)],
        ['doShift', 'c092b0a21437eb6e5b20a8437ee815ef60f3877970c6238262b2c7a1f8942f5b', ALL, bound(:do_pop)],
        ['buildArray', 'f2b2aba9221fb3941730daf2d592755a500adac1775c1b8dc76ede35bb7df1ae', %i[0ad2095],
         bound(:build_array, and_pattern: / and (a|an) /)],
        ['buildArray', '4cb57d0e0971868068f245dfb273221740cc2818453d8cfe62e96236b36f7223', ALL - %i[0ad2095],
         bound(:build_array, and_pattern: / and (a|an|some) /)],
        ['buildArrayStr', 'ce5944f83ac9a1f820cc8490c0373299d16d9cf0142da839620cfef8f7d28416', UNTIL_2022,
         bound(:build_array_str, mode: :percent_only)],
        ['buildArrayStr', 'b5d25bfc2d5cb28976f93bd3b5d3e8d21edc773a987b9881daadaafbe2d2337d', SINCE_2024,
         bound(:build_array_str, mode: :else_if)],
        ['findMax', '364e9223c9e5c550586ee27603f594a4b56c8528b0b0b424d7b17c2b23081f95', ALL, bound(:find_extreme)],
        ['findMin', '214b749c307b4a7ca92bd1aee74908259bf2b83c4eacf48be8c396d1936dc0c4', ALL, bound(:find_extreme)],
        ['findMaxIndex', 'e67a4241add33994a8a57d49e900fd967d1e4c6a09ff1e2b85d56ff3096ed228', ALL, bound(:find_extreme)],
        ['findMinIndex', '4af8660d0a977f400d4d4a61992fa769bdbdbbf7ab59acd5b58518d46d35888b', ALL, bound(:find_extreme)],
        ['findMaxGlobal', 'b92fee5cd1dc142ad7756a3ae4d9d26f0b5878589f625c0d44eb2b36a74aabab', ALL, bound(:find_extreme_global)],
        ['findMinGlobal', '0a39baf26a52a85c2c14ba598a02d5f9fa60b958a63b75c2f6a65559c690341c', ALL, bound(:find_extreme_global)],
        ['zipArrays', '37ab850af8191fb4b9bc9aec38d8d6f21848e6bf2552d85bc37fcf812794f499', SINCE_2024, bound(:zip_arrays)]
      ].to_h { |name, fingerprint, copies, callable| [fingerprint, Body.new(name, callable, copies.freeze).freeze] }.freeze

      # @param copy [Symbol] a {COPIES} key
      # @return [Hash{String=>#call}] the functions that version declares
      def functions_of(copy)
        FUNCTION_BODIES.values.select { |body| body.copies.include?(copy) }.to_h { |body| [body.name, body.callable] }
      end

      # @param declaration [JsSource::Declaration]
      # @return [#call] what calling the declared function does: a known body's replay, or
      #   {JsRuntime::Unsupported} naming the function
      def callable_for(declaration)
        body = FUNCTION_BODIES[declaration.fingerprint]
        return body.callable if body&.name == declaration.name

        name = declaration.name
        lambda do |_runtime, _args|
          raise JsRuntime::Unsupported, "#{name}() -- a function body this port does not recognise " \
                                        '(only the published js_arrays.js versions are replayed)'
        end
      end

      SKILLDATA_SORT = Source.new('DR-Genie-Scripts SkillData.cmd sort block (rows 12-24)', nil, method(:skilldata_sort), nil)
      UBER_TEXT_TO_NUMBER = Source.new('ubercombat uber.cmd TEXT_TO_NUMBER block (rows 36753-36824)',
                                       { 'textToNumber' => method(:text_to_number) }, method(:text_to_number), %w[map magnitude_map])

      # The recognised `<% %>` blocks, by {JsSource.fingerprint}.
      SOURCES = {
        '565d6faedebffffc836f0ef5c773ba7e537900bf5dea0f00a244214c3b44a689' => SKILLDATA_SORT,
        '1ed912937a6dd9c2f560e7f985cb70ed6bcd237f48c5cd9382cffa8fb0412fd2' => UBER_TEXT_TO_NUMBER
      }.freeze

      # @param source [String] the block RunJsblock executes
      # @return [Source, nil] the recognised block it is
      def source_for(source)
        SOURCES[JsSource.fingerprint(source)] # nil: no key
      end
    end
  end
end
