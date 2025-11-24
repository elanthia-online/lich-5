# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Parameter object for login information
      # Encapsulates all data needed for character login with favorites support
      class LoginParams
        attr_accessor :user_id, :password, :char_name, :game_code, :game_name,
                      :frontend, :custom_launch, :custom_launch_dir,
                      :is_favorite, :favorite_order, :favorite_added

        # Initializes a new LoginParams instance with favorites support
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
        # @option params [Boolean] :is_favorite Whether character is marked as favorite
        # @option params [Integer] :favorite_order Order in favorites list
        # @option params [String] :favorite_added ISO8601 timestamp when added to favorites
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
          @is_favorite = params[:is_favorite] || false
          @favorite_order = params[:favorite_order]
          @favorite_added = params[:favorite_added]
        end

        # Converts the parameter object to a hash
        #
        # @return [Hash] Hash representation of login parameters with favorites info
        def to_h
          {
            user_id: @user_id,
            password: @password,
            char_name: @char_name,
            game_code: @game_code,
            game_name: @game_name,
            frontend: @frontend,
            custom_launch: @custom_launch,
            custom_launch_dir: @custom_launch_dir,
            is_favorite: @is_favorite,
            favorite_order: @favorite_order,
            favorite_added: @favorite_added
          }
        end

        # Checks if this character is marked as a favorite
        #
        # @return [Boolean] True if character is a favorite
        def favorite?
          @is_favorite == true
        end

        # Creates a character identifier for favorites operations
        #
        # @return [Hash] Character identifier hash
        def character_id
          {
            username: @user_id,
            char_name: @char_name,
            game_code: @game_code
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
      # Encapsulates all callback functions for UI components with favorites support
      class CallbackParams
        attr_accessor :on_play, :on_remove, :on_save, :on_error,
                      :on_theme_change, :on_layout_change, :on_sort_change,
                      :on_add_character, :on_favorites_change, :on_favorites_reorder

        # Initializes a new CallbackParams instance with favorites support
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
        # @option params [Proc] :on_favorites_change Callback for favorites status changes
        # @option params [Proc] :on_favorites_reorder Callback for favorites reordering
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
          @on_favorites_change = params[:on_favorites_change]
          @on_favorites_reorder = params[:on_favorites_reorder]
        end

        # Converts the parameter object to a hash
        #
        # @return [Hash] Hash representation of callbacks with favorites support
        def to_h
          {
            on_play: @on_play,
            on_remove: @on_remove,
            on_save: @on_save,
            on_error: @on_error,
            on_theme_change: @on_theme_change,
            on_layout_change: @on_layout_change,
            on_sort_change: @on_sort_change,
            on_add_character: @on_add_character,
            on_favorites_change: @on_favorites_change,
            on_favorites_reorder: @on_favorites_reorder
          }
        end
      end
    end
  end
end
