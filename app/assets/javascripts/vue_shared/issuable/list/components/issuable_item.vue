<script>
import {
  GlBadge,
  GlLink,
  GlIcon,
  GlLabel,
  GlFormCheckbox,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { STATUS_OPEN, STATUS_CLOSED } from '~/issues/constants';
import { isScopedLabel } from '~/lib/utils/common_utils';
import { isExternal, setUrlFragment } from '~/lib/utils/url_utility';
import { __, n__, sprintf } from '~/locale';
import IssuableAssignees from '~/issuable/components/issue_assignees.vue';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import { STATE_OPEN, STATE_CLOSED } from '~/work_items/constants';
import { isAssigneesWidget, isLabelsWidget } from '~/work_items/utils';

export default {
  components: {
    GlBadge,
    GlLink,
    GlIcon,
    GlLabel,
    GlFormCheckbox,
    GlSprintf,
    IssuableAssignees,
    WorkItemTypeIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin],
  props: {
    hasScopedLabelsFeature: {
      type: Boolean,
      required: false,
      default: false,
    },
    issuableSymbol: {
      type: String,
      required: true,
    },
    issuable: {
      type: Object,
      required: true,
    },
    labelFilterParam: {
      type: String,
      required: false,
      default: 'label_name',
    },
    showCheckbox: {
      type: Boolean,
      required: true,
    },
    checked: {
      type: Boolean,
      required: false,
      default: false,
    },
    showWorkItemTypeIcon: {
      type: Boolean,
      required: false,
      default: false,
    },
    isActive: {
      type: Boolean,
      required: false,
      default: false,
    },
    preventRedirect: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    issuableId() {
      return getIdFromGraphQLId(this.issuable.id);
    },
    issuableIid() {
      return this.issuable.iid;
    },
    author() {
      return this.issuable.author || {};
    },
    externalAuthor() {
      return this.issuable.externalAuthor;
    },
    webUrl() {
      return this.issuable.gitlabWebUrl || this.issuable.webUrl;
    },
    authorId() {
      return getIdFromGraphQLId(this.author.id);
    },
    isIssuableUrlExternal() {
      return isExternal(this.webUrl ?? '');
    },
    reference() {
      return this.issuable.reference || `${this.issuableSymbol}${this.issuable.iid}`;
    },
    type() {
      return this.issuable.type || this.issuable.workItemType?.name.toUpperCase();
    },
    labels() {
      return (
        this.issuable.labels?.nodes ||
        this.issuable.labels ||
        this.issuable.widgets?.find(isLabelsWidget)?.labels.nodes ||
        []
      );
    },
    labelIdsString() {
      return JSON.stringify(this.labels.map((label) => getIdFromGraphQLId(label.id)));
    },
    assignees() {
      return (
        this.issuable.assignees?.nodes ||
        this.issuable.assignees ||
        this.issuable.widgets?.find(isAssigneesWidget)?.assignees.nodes ||
        []
      );
    },
    createdAt() {
      return this.timeFormatted(this.issuable.createdAt);
    },
    isNotOpen() {
      return ![STATUS_OPEN, STATE_OPEN].includes(this.issuable.state);
    },
    isClosed() {
      return [STATUS_CLOSED, STATE_CLOSED].includes(this.issuable.state);
    },
    timestamp() {
      return this.isClosed && this.issuable.closedAt
        ? this.issuable.closedAt
        : this.issuable.updatedAt;
    },
    formattedTimestamp() {
      if (this.isClosed && this.issuable.closedAt) {
        return sprintf(__('closed %{timeago}'), {
          timeago: this.timeFormatted(this.issuable.closedAt),
        });
      }
      if (this.issuable.updatedAt !== this.issuable.createdAt) {
        return sprintf(__('updated %{timeAgo}'), {
          timeAgo: this.timeFormatted(this.issuable.updatedAt),
        });
      }
      return undefined;
    },
    issuableTitleProps() {
      if (this.isIssuableUrlExternal) {
        return {
          target: '_blank',
        };
      }
      return {};
    },
    taskStatus() {
      const { completedCount, count } = this.issuable.taskCompletionStatus || {};
      if (!count) {
        return undefined;
      }

      return sprintf(
        n__(
          '%{completedCount} of %{count} checklist item completed',
          '%{completedCount} of %{count} checklist items completed',
          count,
        ),
        { completedCount, count },
      );
    },
    notesCount() {
      return this.issuable.userDiscussionsCount ?? this.issuable.userNotesCount;
    },
    showDiscussions() {
      return typeof this.notesCount === 'number';
    },
    showIssuableMeta() {
      return Boolean(
        this.hasSlotContents('status') ||
          this.hasSlotContents('statistics') ||
          this.showDiscussions ||
          this.issuable.assignees,
      );
    },
    issuableNotesLink() {
      return setUrlFragment(this.webUrl, 'notes');
    },
    statusBadgeVariant() {
      if (this.isMergeRequest && this.isClosed) {
        return 'danger';
      }

      return 'info';
    },
    isMergeRequest() {
      // eslint-disable-next-line no-underscore-dangle
      return this.issuable.__typename === 'MergeRequest';
    },
  },
  methods: {
    hasSlotContents(slotName) {
      // eslint-disable-next-line @gitlab/vue-prefer-dollar-scopedslots
      return Boolean(this.$slots[slotName]);
    },
    scopedLabel(label) {
      const allowsScopedLabels =
        this.hasScopedLabelsFeature ||
        this.issuable.widgets?.find(isLabelsWidget)?.allowsScopedLabels;
      return allowsScopedLabels && isScopedLabel(label);
    },
    labelTitle(label) {
      return label.title || label.name;
    },
    labelTarget(label) {
      const value = encodeURIComponent(this.labelTitle(label));
      return `?${this.labelFilterParam}[]=${value}`;
    },
    /**
     * This is needed as an independent method since
     * when user changes current page, `$refs.authorLink`
     * will be null until next page results are loaded & rendered.
     */
    getAuthorPopoverTarget() {
      if (this.$refs.authorLink) {
        return this.$refs.authorLink.$el;
      }
      return '';
    },
    handleIssuableItemClick(e) {
      if (e.metaKey || e.ctrlKey || !this.preventRedirect) {
        return;
      }
      e.preventDefault();
      this.$emit('select-issuable', { iid: this.issuableIid, webUrl: this.webUrl });
    },
  },
};
</script>

<template>
  <li
    :id="`issuable_${issuableId}`"
    class="issue gl-display-flex! gl-px-5!"
    :class="{ closed: issuable.closedAt, 'gl-bg-blue-50': isActive }"
    :data-labels="labelIdsString"
    :data-qa-issue-id="issuableId"
    data-testid="issuable-item-wrapper"
  >
    <gl-form-checkbox
      v-if="showCheckbox"
      class="issue-check gl-mr-0"
      :checked="checked"
      :data-id="issuableId"
      :data-iid="issuableIid"
      :data-type="type"
      @input="$emit('checked-input', $event)"
    >
      <span class="gl-sr-only">{{ issuable.title }}</span>
    </gl-form-checkbox>
    <div class="issuable-main-info">
      <div data-testid="issuable-title" class="issue-title title">
        <work-item-type-icon
          v-if="showWorkItemTypeIcon"
          class="gl-mr-2"
          :work-item-type="type"
          show-tooltip-on-hover
        />
        <gl-icon
          v-if="issuable.confidential"
          v-gl-tooltip
          name="eye-slash"
          :title="__('Confidential')"
          :aria-label="__('Confidential')"
        />
        <gl-icon
          v-if="issuable.hidden"
          v-gl-tooltip
          name="spam"
          :title="__('This issue is hidden because its author has been banned.')"
          :aria-label="__('Hidden')"
        />
        <gl-link
          class="issue-title-text"
          dir="auto"
          :href="webUrl"
          data-testid="issuable-title-link"
          v-bind="issuableTitleProps"
          @click="handleIssuableItemClick"
        >
          {{ issuable.title }}
          <gl-icon v-if="isIssuableUrlExternal" name="external-link" class="gl-ml-2" />
        </gl-link>
        <span
          v-if="taskStatus"
          class="task-status gl-display-none gl-sm-display-inline-block! gl-ml-2 gl-font-sm"
          data-testid="task-status"
        >
          {{ taskStatus }}
        </span>
      </div>
      <div class="issuable-info">
        <slot v-if="hasSlotContents('reference')" name="reference"></slot>
        <span v-else data-testid="issuable-reference" class="issuable-reference">
          {{ reference }}
        </span>
        <span class="gl-display-none gl-sm-display-inline">
          <span aria-hidden="true">&middot;</span>
          <span class="issuable-authored gl-mr-3">
            <gl-sprintf v-if="author.name" :message="__('created %{timeAgo} by %{author}')">
              <template #timeAgo>
                <span
                  v-gl-tooltip.bottom
                  :title="tooltipTitle(issuable.createdAt)"
                  data-testid="issuable-created-at"
                >
                  {{ createdAt }}
                </span>
              </template>
              <template #author>
                <span v-if="externalAuthor" data-testid="external-author"
                  >{{ externalAuthor }} {{ __('via') }}</span
                >
                <slot v-if="hasSlotContents('author')" name="author"></slot>
                <gl-link
                  v-else
                  :data-user-id="authorId"
                  :data-username="author.username"
                  :data-name="author.name"
                  :data-avatar-url="author.avatarUrl"
                  :href="author.webUrl"
                  data-testid="issuable-author"
                  class="author-link js-user-link gl-font-sm gl-text-gray-500!"
                >
                  <span class="author">{{ author.name }}</span>
                </gl-link>
              </template>
            </gl-sprintf>
            <gl-sprintf v-else :message="__('created %{timeAgo}')">
              <template #timeAgo>
                <span
                  v-gl-tooltip.bottom
                  :title="tooltipTitle(issuable.createdAt)"
                  data-testid="issuable-created-at"
                >
                  {{ createdAt }}
                </span>
              </template>
            </gl-sprintf>
          </span>
          <slot name="timeframe"></slot>
        </span>
        <p
          v-if="labels.length"
          role="group"
          :aria-label="__('Labels')"
          class="gl-mt-1 gl-mb-0 gl-display-flex gl-flex-wrap gl-gap-2"
        >
          <gl-label
            v-for="(label, index) in labels"
            :key="index"
            :background-color="label.color"
            :title="labelTitle(label)"
            :description="label.description"
            :scoped="scopedLabel(label)"
            :target="labelTarget(label)"
            size="sm"
          />
        </p>
      </div>
    </div>
    <div class="issuable-meta">
      <ul v-if="showIssuableMeta" class="controls">
        <!-- eslint-disable-next-line @gitlab/vue-prefer-dollar-scopedslots -->
        <li v-if="$slots.status" data-testid="issuable-status">
          <gl-badge v-if="isNotOpen" size="sm" :variant="statusBadgeVariant">
            <slot name="status"></slot>
          </gl-badge>
          <slot v-else name="status"></slot>
        </li>
        <slot name="pipeline-status"></slot>
        <li v-if="assignees.length">
          <issuable-assignees
            :assignees="assignees"
            :icon-size="16"
            :max-visible="4"
            img-css-classes="gl-mr-2!"
            class="gl-align-items-center gl-display-flex"
          />
        </li>
        <slot name="statistics"></slot>
        <li
          v-if="showDiscussions"
          class="gl-display-none gl-sm-display-block"
          data-testid="issuable-comments"
        >
          <gl-link
            v-gl-tooltip.top
            :title="__('Comments')"
            :href="issuableNotesLink"
            :class="{ 'no-comments': !notesCount }"
            class="gl-reset-color!"
          >
            <gl-icon name="comments" />
            {{ notesCount }}
          </gl-link>
        </li>
      </ul>
      <div
        v-gl-tooltip.bottom
        class="gl-text-gray-500 gl-display-none gl-sm-display-inline-block"
        :title="tooltipTitle(timestamp)"
        data-testid="issuable-timestamp"
      >
        {{ formattedTimestamp }}
      </div>
    </div>
  </li>
</template>
