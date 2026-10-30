# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Builder
          CLASSES = %w[Window Box HBox VBox Grid Table Frame ScrolledWindow Viewport
                       Notebook Expander Label Entry SearchEntry Button ToggleButton
                       CheckButton RadioButton SpinButton ComboBoxText ComboBox TextView
                       TextBuffer Separator HSeparator TreeView TreeViewColumn
                       TreeSelection ListStore TreeStore CellRendererText CellRendererToggle
                       CellRendererCombo Adjustment].to_h { |name| ["Gtk#{name}", Gtk.const_get(name, false)] }.freeze
          COLUMN_TYPES = { 'gchararray' => String, 'gint' => Integer, 'guint' => Integer,
                           'gfloat' => Float, 'gdouble' => Float, 'gboolean' => TrueClass }.freeze
          CONSTRUCTOR_PROPERTIES = {
            'GtkBox' => %w[orientation spacing], 'GtkHBox' => %w[homogeneous spacing], 'GtkVBox' => %w[homogeneous spacing],
            'GtkTable' => %w[n-rows n-columns],
            'GtkAdjustment' => %w[value lower upper step-increment page-increment page-size],
            'GtkSpinButton' => %w[adjustment climb-rate digits], 'GtkFrame' => %w[label], 'GtkExpander' => %w[label],
            'GtkComboBox' => %w[has-entry model], 'GtkComboBoxText' => %w[has-entry model], 'GtkTextView' => %w[buffer],
            'GtkSeparator' => %w[orientation], 'GtkRadioButton' => %w[group label],
            'GtkTreeView' => %w[model], 'GtkCellRendererCombo' => %w[model],
          }.freeze
          ELEMENTS = {
            'interface' => [%w[requires object], []],
            'requires' => [[], %w[lib version]],
            'object' => [%w[property child signal columns data items attributes], %w[class id]],
            'property' => [[], %w[name translatable comments context]],
            'child' => [%w[object packing attributes placeholder], %w[type internal-child]],
            'packing' => [%w[property], []], 'placeholder' => [[], []],
            'columns' => [%w[column], []], 'column' => [[], %w[type]],
            'data' => [%w[row], []], 'row' => [%w[col row], []], 'col' => [[], %w[id translatable]],
            'items' => [%w[item], []], 'item' => [[], %w[id translatable]],
            'attributes' => [%w[attribute], []], 'attribute' => [[], %w[name value]],
            'signal' => [[], %w[name handler swapped after]],
          }.freeze
          COMMON = {
            'name' => [:name=, :text],
            'can-focus' => [:can_focus=, :boolean],
            'visible' => [:visible, :boolean], 'sensitive' => [:sensitive=, :boolean],
            'width-request' => [:set_width_request, :integer], 'height-request' => [:set_height_request, :integer],
            'border-width' => [:set_border_width, :integer], 'tooltip-text' => [:set_tooltip_text, :text],
            'halign' => [:halign=, :symbol], 'valign' => [:valign=, :symbol], 'hexpand' => [:set_hexpand, :boolean], 'vexpand' => [:set_vexpand, :boolean],
            'margin-start' => [:set_margin_start, :integer], 'margin-end' => [:set_margin_end, :integer],
            'margin-left' => [:set_margin_left, :integer], 'margin-right' => [:set_margin_right, :integer],
            'margin-top' => [:set_margin_top, :integer], 'margin-bottom' => [:set_margin_bottom, :integer],
          }.freeze
          PROPERTIES = {
            Notebook           => { 'show-tabs' => [:show_tabs=, :boolean] },
            Window             => { 'title' => [:title=, :text], 'default-width' => [:default_width=, :integer],
                        'default-height' => [:default_height=, :integer], 'resizable' => [:resizable=, :boolean], 'modal' => [:modal=, :boolean] },
            Grid               => { 'row-spacing' => [:row_spacing=, :integer], 'column-spacing' => [:column_spacing=, :integer],
                      'column-homogeneous' => [:column_homogeneous=, :boolean], 'row-homogeneous' => [:row_homogeneous=, :boolean] },
            Label              => { 'label' => [:text=, :text], 'wrap' => [:wrap=, :boolean], 'xalign' => [:xalign=, :number], 'yalign' => [:yalign=, :number],
                       'single-line-mode' => [:single_line_mode=, :boolean],
                       'xpad' => [:xpad=, :integer], 'ypad' => [:ypad=, :integer], 'angle' => [:angle=, :number], 'justify' => [:justify=, :symbol],
                       'selectable' => [:set_selectable, :boolean], 'width-chars' => [:set_width_chars, :integer], 'use-markup' => [:use_markup=, :boolean] },
            Entry              => { 'text' => [:text=, :text], 'placeholder-text' => [:placeholder_text=, :text],
                       'max-length' => [:max_length=, :integer],
                       'editable' => [:editable=, :boolean], 'xalign' => [:xalign=, :number], 'width-chars' => [:set_width_chars, :integer],
                       'max-width-chars' => [:set_max_width_chars, :integer] },
            Button             => { 'label' => [:label=, :text], 'receives-default' => [:receives_default=, :boolean] },
            SearchEntry        => { 'primary-icon-name'        => [:primary_icon_name=, :text],
                                    'primary-icon-activatable' => [:primary_icon_activatable=, :boolean],
                                    'primary-icon-sensitive'   => [:primary_icon_sensitive=, :boolean] },
            CheckButton        => { 'draw-indicator' => [:draw_indicator=, :boolean], 'receives-default' => [:receives_default=, :boolean],
                                   'always-show-image' => [:always_show_image=, :boolean] },
            Frame              => { 'label-xalign' => [:label_xalign=, :number], 'shadow-type' => [:shadow_type=, :symbol] },
            ScrolledWindow     => { 'shadow-type' => [:shadow_type=, :symbol] },
            ToggleButton       => { 'label' => [:label=, :text], 'active' => [:set_active, :boolean] },
            RadioButton        => { 'active' => [:set_active, :boolean] },
            SpinButton         => { 'value' => [:set_value, :number], 'digits' => [:digits=, :integer], 'numeric' => [:numeric=, :boolean] },
            ComboBox           => { 'active' => [:active=, :integer], 'entry-text-column' => [:entry_text_column=, :integer] },
            TextView           => { 'editable' => [:editable=, :boolean], 'cursor-visible' => [:cursor_visible=, :boolean],
                          'wrap-mode' => [:wrap_mode=, :symbol], 'accepts-tab' => [:accepts_tab=, :boolean] },
            TextBuffer         => { 'text' => [:set_text, :text] },
            Expander           => { 'label' => [:set_label, :text], 'expanded' => [:set_expanded, :boolean] },
            TreeView           => { 'headers-visible' => [:headers_visible=, :boolean], 'search-column' => [:search_column=, :integer],
                                   'enable-search' => [:enable_search=, :boolean], 'enable-grid-lines' => [:enable_grid_lines=, :symbol],
                                   'activate-on-single-click' => [:activate_on_single_click=, :boolean],
                                   'fixed-height-mode' => [:fixed_height_mode=, :boolean] },
            TreeViewColumn     => { 'title' => [:title=, :text], 'resizable' => [:resizable=, :boolean],
                                'clickable' => [:clickable=, :boolean],
                                'visible' => [:visible=, :boolean], 'fixed-width' => [:fixed_width=, :integer],
                                'sort-column-id' => [:sort_column_id=, :integer], 'sizing' => [:sizing=, :symbol] },
            TreeSelection      => { 'mode' => [:mode=, :symbol] },
            CellRendererText   => { 'editable' => [:editable=, :boolean], 'xalign' => [:xalign=, :number] },
            CellRendererToggle => { 'activatable' => [:activatable=, :boolean] },
            CellRendererCombo  => { 'text-column' => [:text_column=, :integer], 'has-entry' => [:has_entry=, :boolean] },
          }.freeze
        end
      end
    end
  end
end
