# frozen_string_literal: true

module Gitlab
  module UsageDataCounters
    module WorkItemActivityUniqueCounter
      WORK_ITEM_TITLE_CHANGED = 'users_updating_work_item_title'

      class << self
        def track_work_item_title_changed_action(author:)
          track_unique_action(WORK_ITEM_TITLE_CHANGED, author)
        end

        private

        def track_unique_action(action, author)
          return unless author

          Gitlab::UsageDataCounters::HLLRedisCounter.track_event(action, values: author.id)
        end
      end
    end
  end
end
