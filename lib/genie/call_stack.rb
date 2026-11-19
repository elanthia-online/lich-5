# frozen_string_literal: true

module Lich
  module Genie
    # The gosub/return call stack and per-frame block state. Clean-room port of
    # Genie4 Script.cs `CurrentLine` (the stack) + `Line` (a frame). See
    # docs/genie-engine/interpreter-spec.md section 0.
    #
    # Frame 0 is the base (main) frame; the last frame is the active one. Every
    # accessor below operates on the ACTIVE frame -- the program counter, block
    # stack, arg list, and skip flags are all per-frame.
    #
    # Block states: :noeval, :evaltrue, :evalfalse, :evalwhiletrue, :evalwhilefalse.
    class CallStack
      # One call-stack frame.
      #
      # @!attribute index [Integer] the program counter (or return address for gosub frames)
      # @!attribute skip_block [Boolean] whether lines are currently being skipped
      # @!attribute target_block_depth [Integer] block depth at which skipping stops
      # @!attribute block_list [Array<Symbol>] nested block-state stack
      # @!attribute arg_list [Array<String>] $0..$n for this frame
      # @!attribute last_row_was_evaluation [Boolean] single-line if/while/else marker
      Frame = Struct.new(
        :index, :skip_block, :target_block_depth,
        :block_list, :arg_list, :last_row_was_evaluation
      )

      def initialize
        @frames = [new_frame]
      end

      # @return [Integer] number of frames on the stack
      def count
        @frames.length
      end

      # --- program counter --------------------------------------------------

      # @return [Integer] the active frame's PC
      def line_value
        active.index
      end

      # @param value [Integer]
      # @return [Integer]
      def line_value=(value)
        active.index = value
      end

      # --- gosub / return ---------------------------------------------------

      # Push a new frame (gosub). Its return address is +index+; its arg list is
      # built from +argument+ ($0 = the full string, $1..$n = ParseArgs tokens).
      #
      # @param index [Integer] the return address (the gosub line's PC)
      # @param argument [String, nil] the text after the label
      # @return [Integer] the new active frame position (count - 1)
      def add_jump(index, argument = nil)
        frame = new_frame(index)
        unless argument.nil? || argument.empty?
          frame.arg_list[0] = argument
          Text.parse_args(argument).each { |token| frame.arg_list << token }
        end
        @frames << frame
        @frames.length - 1
      end

      # Pop the active frame (return). Never removes the base frame.
      #
      # @return [Boolean] true if a frame was popped, false if only the base remained
      def remove_jump
        return false if @frames.length <= 1

        @frames.pop
        true
      end

      # --- block state (per active frame) -----------------------------------

      # @param state [Symbol]
      # @return [void]
      def add_block(state = :noeval)
        active.block_list.push(state)
      end

      # @return [Boolean] true if a block was popped
      def remove_block
        return false if active.block_list.empty?

        active.block_list.pop
        true
      end

      # @return [Symbol] the top block state, or :noeval if none
      def block_value
        active.block_list.last || :noeval
      end

      # @param state [Symbol]
      # @return [Symbol]
      def block_value=(state)
        if active.block_list.empty?
          active.block_list.push(state)
        else
          active.block_list[-1] = state
        end
      end

      # @return [Integer] active frame's block depth
      def block_count
        active.block_list.length
      end

      # Clear only the active frame's block stack (used on goto / match jumps).
      # @return [void]
      def clear_blocks
        active.block_list.clear
      end

      # --- skip flags / args (per active frame) -----------------------------

      # @return [Boolean]
      def skip_block
        active.skip_block
      end

      # @param value [Boolean]
      def skip_block=(value)
        active.skip_block = value
      end

      # @return [Integer]
      def target_block_depth
        active.target_block_depth
      end

      # @param value [Integer]
      def target_block_depth=(value)
        active.target_block_depth = value
      end

      # @return [Boolean]
      def last_row_was_evaluation
        active.last_row_was_evaluation
      end

      # @param value [Boolean]
      def last_row_was_evaluation=(value)
        active.last_row_was_evaluation = value
      end

      # @return [Array<String>] the active frame's arg list
      def arg_list
        active.arg_list
      end

      # Rebind the active frame's arg list to +list+ BY REFERENCE (CurrentLine.ArgList's
      # setter, Script.cs:85-98 R). `if`/`eval` hand it Eval's result list after a matchre()
      # hit (Script.cs:3263-3266, 3569-3572 R), so every later evaluation clears this frame's
      # $0..$n, and a matchre/waitforre/matchwait capture written into it (in place) lands
      # in Eval's list. The binding stays on the frame across gosub/return.
      # @param list [Array<String>]
      # @return [Array<String>]
      def arg_list=(list)
        active.arg_list = list
      end

      # Reset the entire stack to a single empty base frame (gosub clear / action jump).
      # @return [void]
      def clear
        @frames = [new_frame]
      end

      private

      def active
        @frames.last
      end

      def new_frame(index = 0)
        Frame.new(index, false, 0, [], [], false)
      end
    end
  end
end
