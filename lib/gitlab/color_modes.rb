# frozen_string_literal: true

module Gitlab
  # Module containing GitLab's color mode definitions and helper methods
  # for accessing them.
  module ColorModes
    # Color mode ID used when no `default_color_mode` configuration setting is provided.
    APPLICATION_DEFAULT = 1
    APPLICATION_DARK = 2

    # Struct class representing a single Mode
    Mode = Struct.new(:id, :name, :css_class)

    def self.available_modes
      [
        Mode.new(APPLICATION_DEFAULT, s_('ColorMode|Light'), 'gl-light'),
        Mode.new(APPLICATION_DARK, s_('ColorMode|Dark (alpha)'), 'gl-dark')
      ]
    end

    # Get a Mode by its ID
    #
    # If the ID is invalid, returns the default Mode.
    #
    # id - Integer ID
    #
    # Returns a Mode
    def self.by_id(id)
      available_modes.detect { |s| s.id == id } || default
    end

    # Get the default Mode
    #
    # Returns a Mode
    def self.default
      by_id(1)
    end

    # Get the Mode for the specified user, or the default
    #
    # user - User record
    #
    # Returns a Mode
    def self.for_user(user)
      if user
        by_id(user.color_mode_id)
      else
        default
      end
    end

    def self.valid_ids
      available_modes.map(&:id)
    end
  end
end
