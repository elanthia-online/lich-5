# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Parameter object for login information
      # Encapsulates all data needed for character login
      class LoginParams
        attr_accessor :user_id, :password, :char_name, :game_code, :game_name,
                      :frontend, :custom_launch, :custom_launch_dir

        # Initializes a new LoginParams instance
        #
        # @param params [Hash] Hash of login parameters
        # @option params [String] :user_id User ID/account name
        # @option params [String] :password User password
        # @option params [String] :char_name Character name
        # @option params [String] :game_code Game code
        # @option params [String] :game_name Game name
        # @option params [String] :frontend Frontend to use (stormfront, wizard, avalon)
        # @option params [String] :custom_launch Custom launch command
        # @option params [String] :custom_launch_dir Custom launch directory
        # @return [LoginParams] New instance
        def initialize(params = {})
          @user_id = params[:user_id]
          @password = params[:password]
          @char_name = params[:char_name]
          @game_code = params[:game_code]
          @game_name = params[:game_name]
          @frontend = params[:frontend]
          @custom_launch = params[:custom_launch]
          @custom_launch_dir = params[:custom_launch_dir]
        end

        # Converts the parameter object to a hash
        #
        # @return [Hash] Hash representation of login parameters
        def to_h
          {
            user_id: @user_id,
            password: @password,
            char_name: @char_name,
            game_code: @game_code,
            game_name: @game_name,
            frontend: @frontend,
            custom_launch: @custom_launch,
            custom_launch_dir: @custom_launch_dir
          }
        end
      end

      # Parameter object for UI configuration
      # Encapsulates all data needed for UI configuration
      class UIConfig
        attr_accessor :theme_state, :tab_layout_state, :autosort_state

        # Initializes a new UIConfig instance
        #
        # @param params [Hash] Hash of UI configuration parameters
        # @option params [Boolean] :theme_state Whether dark theme is enabled
        # @option params [Boolean] :tab_layout_state Whether tab layout is enabled
        # @option params [Boolean] :autosort_state Whether auto-sorting is enabled
        # @return [UIConfig] New instance
        def initialize(params = {})
          @theme_state = params[:theme_state]
          @tab_layout_state = params[:tab_layout_state]
          @autosort_state = params[:autosort_state]
        end

        # Converts the parameter object to a hash
        #
        # @return [Hash] Hash representation of UI configuration
        def to_h
          {
            theme_state: @theme_state,
            tab_layout_state: @tab_layout_state,
            autosort_state: @autosort_state
          }
        end
      end

      # Parameter object for callbacks
      # Encapsulates all callback functions for UI components
      class CallbackParams
        attr_accessor :on_play, :on_remove, :on_save, :on_error,
                      :on_theme_change, :on_layout_change, :on_sort_change,
                      :on_add_character

        # Initializes a new CallbackParams instance
        #
        # @param params [Hash] Hash of callback parameters
        # @option params [Proc] :on_play Callback for play button
        # @option params [Proc] :on_remove Callback for remove button
        # @option params [Proc] :on_save Callback for saving entries
        # @option params [Proc] :on_error Callback for error handling
        # @option params [Proc] :on_theme_change Callback for theme changes
        # @option params [Proc] :on_layout_change Callback for layout changes
        # @option params [Proc] :on_sort_change Callback for sort changes
        # @option params [Proc] :on_add_character Callback for adding characters
        # @return [CallbackParams] New instance
        def initialize(params = {})
          @on_play = params[:on_play]
          @on_remove = params[:on_remove]
          @on_save = params[:on_save]
          @on_error = params[:on_error]
          @on_theme_change = params[:on_theme_change]
          @on_layout_change = params[:on_layout_change]
          @on_sort_change = params[:on_sort_change]
          @on_add_character = params[:on_add_character]
        end

        # Converts the parameter object to a hash
        #
        # @return [Hash] Hash representation of callbacks
        def to_h
          {
            on_play: @on_play,
            on_remove: @on_remove,
            on_save: @on_save,
            on_error: @on_error,
            on_theme_change: @on_theme_change,
            on_layout_change: @on_layout_change,
            on_sort_change: @on_sort_change,
            on_add_character: @on_add_character
          }
        end
      end
    end
  end
end
