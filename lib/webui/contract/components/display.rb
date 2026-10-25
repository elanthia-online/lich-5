# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      class << self
        private

        # Supplies the display component declarations to the Contract facade.
        # @return [Hash] base schemas in declaration order
        def display_schemas
          {
            text: {
              properties: { content: property(string(:display_text), required: true), wrap: property(BOOL, default: true),
                            fragments: property(array(BODY, max: BOUNDS[:collection])),
                            max_width_chars: property(integer(min: 1, max: 1024)),
                            line_limit: property(union(integer(min: -1, max: -1), integer(min: 1, max: 1024))),
                            ellipsize: property(enum(:middle, :end)) },
              children: :none, events: {}, value: nil,
            },
            markdown: {
              properties: { content: property(string(:rich_text), required: true) }, children: :none, events: {}, value: nil,
            },
            log: {
              properties: {
                lines: property(array(union(string(:log_line), array(string(:log_line), max: BOUNDS[:collection])), max: BOUNDS[:log_lines]), required: true),
                max_lines: property(integer(min: 1, max: BOUNDS[:log_lines]), required: true),
                follow: property(BOOL, default: true), wrap: property(enum(:word, :word_char, :none), default: :word),
              }, children: :none, events: {}, value: nil,
            },
            progress: {
              properties: {
                value: property(number(min: 0.0, max: 1.0)), label: property(SHORT),
                indeterminate: property(BOOL, default: false),
              }, children: :none, events: {}, value: nil,
            },
            image: {
              properties: {
                src: property(string(:body_text), required: true), alt: property(SHORT),
                scale: property(number(min: 0.1, max: 8.0), default: 1.0),
              }, children: :none, events: {}, value: nil,
            },
          }
        end
      end
    end
  end
end
