<script>
import { GlSkeletonLoader, GlModal } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import { scrollToTargetOnResize } from '~/lib/utils/resize_observer';
import { TYPENAME_DISCUSSION, TYPENAME_NOTE } from '~/graphql_shared/constants';
import SystemNote from '~/work_items/components/notes/system_note.vue';
import WorkItemNotesActivityHeader from '~/work_items/components/notes/work_item_notes_activity_header.vue';
import {
  i18n,
  DEFAULT_PAGE_SIZE_NOTES,
  WORK_ITEM_NOTES_FILTER_ALL_NOTES,
  WORK_ITEM_NOTES_FILTER_ONLY_COMMENTS,
  WORK_ITEM_NOTES_FILTER_ONLY_HISTORY,
} from '~/work_items/constants';
import { ASC, DESC } from '~/notes/constants';
import { autocompleteDataSources, markdownPreviewPath } from '~/work_items/utils';
import {
  updateCacheAfterCreatingNote,
  updateCacheAfterDeletingNote,
} from '~/work_items/graphql/cache_utils';
import { getLocationHash } from '~/lib/utils/url_utility';
import { collapseSystemNotes } from '~/work_items/notes/collapse_utils';
import WorkItemDiscussion from '~/work_items/components/notes/work_item_discussion.vue';
import WorkItemHistoryOnlyFilterNote from '~/work_items/components/notes/work_item_history_only_filter_note.vue';
import workItemNoteCreatedSubscription from '~/work_items/graphql/notes/work_item_note_created.subscription.graphql';
import workItemNoteUpdatedSubscription from '~/work_items/graphql/notes/work_item_note_updated.subscription.graphql';
import workItemNoteDeletedSubscription from '~/work_items/graphql/notes/work_item_note_deleted.subscription.graphql';
import deleteNoteMutation from '../graphql/notes/delete_work_item_notes.mutation.graphql';
import groupWorkItemNotesByIidQuery from '../graphql/notes/group_work_item_notes_by_iid.query.graphql';
import workItemNotesByIidQuery from '../graphql/notes/work_item_notes_by_iid.query.graphql';
import WorkItemAddNote from './notes/work_item_add_note.vue';

export default {
  loader: {
    repeat: 10,
    width: 1000,
    height: 40,
  },
  components: {
    GlSkeletonLoader,
    GlModal,
    SystemNote,
    WorkItemAddNote,
    WorkItemDiscussion,
    WorkItemNotesActivityHeader,
    WorkItemHistoryOnlyFilterNote,
  },
  inject: ['isGroup'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
    isModal: {
      type: Boolean,
      required: false,
      default: false,
    },
    assignees: {
      type: Array,
      required: false,
      default: () => [],
    },
    canSetWorkItemMetadata: {
      type: Boolean,
      required: false,
      default: false,
    },
    reportAbusePath: {
      type: String,
      required: true,
    },
    isDiscussionLocked: {
      type: Boolean,
      required: false,
      default: false,
    },
    isWorkItemConfidential: {
      type: Boolean,
      required: false,
      default: false,
    },
    useH2: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  data() {
    return {
      isLoadingMore: false,
      sortOrder: ASC,
      noteToDelete: null,
      discussionFilter: WORK_ITEM_NOTES_FILTER_ALL_NOTES,
      addNoteKey: uniqueId(`work-item-add-note-${this.workItemId}`),
    };
  },
  computed: {
    initialLoading() {
      return this.$apollo.queries.workItemNotes.loading && !this.isLoadingMore;
    },
    avatarUrl() {
      return window.gon.current_user_avatar_url;
    },
    pageInfo() {
      return this.workItemNotes?.pageInfo;
    },
    hasNextPage() {
      return this.pageInfo?.hasNextPage;
    },
    disableActivityFilterSort() {
      return this.initialLoading || this.isLoadingMore;
    },
    formAtTop() {
      return this.sortOrder === DESC;
    },
    markdownPreviewPath() {
      const { fullPath, isGroup, workItemIid: iid } = this;
      return markdownPreviewPath({ fullPath, iid, isGroup });
    },
    autocompleteDataSources() {
      const { fullPath, isGroup, workItemIid: iid } = this;
      return autocompleteDataSources({ fullPath, iid, isGroup });
    },
    workItemCommentFormProps() {
      return {
        fullPath: this.fullPath,
        workItemId: this.workItemId,
        workItemIid: this.workItemIid,
        workItemType: this.workItemType,
        sortOrder: this.sortOrder,
        isNewDiscussion: true,
        markdownPreviewPath: this.markdownPreviewPath,
        autocompleteDataSources: this.autocompleteDataSources,
        isDiscussionLocked: this.isDiscussionLocked,
        isWorkItemConfidential: this.isWorkItemConfidential,
      };
    },
    notesArray() {
      const notes = this.workItemNotes?.nodes || [];

      let visibleNotes = collapseSystemNotes(notes);

      visibleNotes = visibleNotes.filter((note) => {
        const isSystemNote = this.isSystemNote(note);

        if (this.discussionFilter === WORK_ITEM_NOTES_FILTER_ONLY_COMMENTS && isSystemNote) {
          return false;
        }

        if (this.discussionFilter === WORK_ITEM_NOTES_FILTER_ONLY_HISTORY && !isSystemNote) {
          return false;
        }

        return true;
      });

      if (this.sortOrder === DESC) {
        return [...visibleNotes].reverse();
      }

      return visibleNotes;
    },
    commentsDisabled() {
      return this.discussionFilter === WORK_ITEM_NOTES_FILTER_ONLY_HISTORY;
    },
    targetNoteHash() {
      return getLocationHash();
    },
  },
  apollo: {
    workItemNotes: {
      query() {
        return this.isGroup ? groupWorkItemNotesByIidQuery : workItemNotesByIidQuery;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          iid: this.workItemIid,
          after: this.after,
          pageSize: DEFAULT_PAGE_SIZE_NOTES,
        };
      },
      update(data) {
        const widgets = data.workspace?.workItems?.nodes[0]?.widgets;
        return widgets?.find((widget) => widget.type === 'NOTES')?.discussions || [];
      },
      skip() {
        return !this.workItemIid;
      },
      error() {
        this.$emit('error', i18n.fetchError);
      },
      result() {
        if (this.hasNextPage) {
          this.fetchMoreNotes();
        } else if (this.targetNoteHash) {
          if (this.isModal) {
            this.$emit('has-notes');
          } else {
            scrollToTargetOnResize();
          }
        }
      },
      subscribeToMore: [
        {
          document: workItemNoteCreatedSubscription,
          updateQuery(previousResult, { subscriptionData }) {
            return updateCacheAfterCreatingNote(previousResult, subscriptionData);
          },
          variables() {
            return {
              noteableId: this.workItemId,
            };
          },
          skip() {
            return !this.workItemId || this.hasNextPage;
          },
        },
        {
          document: workItemNoteDeletedSubscription,
          updateQuery(previousResult, { subscriptionData }) {
            return updateCacheAfterDeletingNote(previousResult, subscriptionData);
          },
          variables() {
            return {
              noteableId: this.workItemId,
            };
          },
          skip() {
            return !this.workItemId || this.hasNextPage;
          },
        },
        {
          document: workItemNoteUpdatedSubscription,
          variables() {
            return {
              noteableId: this.workItemId,
            };
          },
          skip() {
            return !this.workItemId;
          },
        },
      ],
    },
  },
  methods: {
    getDiscussionKey(discussion) {
      // discussion key is important like this since after first comment changes
      const discussionId = discussion.notes.nodes[0].id;
      return discussionId.split('/')[discussionId.split('/').length - 1];
    },
    isSystemNote(note) {
      return note.notes.nodes[0].system;
    },
    changeNotesSortOrder(direction) {
      this.sortOrder = direction;
    },
    filterDiscussions(filterValue) {
      this.discussionFilter = filterValue;
    },
    updateKey() {
      this.addNoteKey = uniqueId(`work-item-add-note-${this.workItemId}`);
    },
    reportAbuse(isOpen, reply = {}) {
      this.$emit('openReportAbuse', reply);
    },
    async fetchMoreNotes() {
      this.isLoadingMore = true;
      await this.$apollo.queries.workItemNotes
        .fetchMore({
          variables: {
            fullPath: this.fullPath,
            iid: this.workItemIid,
            after: this.pageInfo?.endCursor,
          },
        })
        .catch((error) => this.$emit('error', error.message));
      this.isLoadingMore = false;
    },
    showDeleteNoteModal(note, discussion) {
      const isLastNote = discussion.notes.nodes.length === 1;
      this.$refs.deleteNoteModal.show();
      this.noteToDelete = { ...note, isLastNote };
    },
    cancelDeletingNote() {
      this.noteToDelete = null;
    },
    async deleteNote() {
      try {
        const { id, isLastNote, discussion } = this.noteToDelete;
        await this.$apollo.mutate({
          mutation: deleteNoteMutation,
          variables: {
            input: {
              id,
            },
          },
          update(cache) {
            const deletedObject = isLastNote
              ? { __typename: TYPENAME_DISCUSSION, id: discussion.id }
              : { __typename: TYPENAME_NOTE, id };
            cache.modify({
              id: cache.identify(deletedObject),
              fields: (_, { DELETE }) => DELETE,
            });
          },
          optimisticResponse: {
            destroyNote: {
              note: null,
              __typename: 'DestroyNotePayload',
            },
          },
        });
      } catch (error) {
        this.$emit('error', __('Something went wrong when deleting a comment. Please try again'));
        Sentry.captureException(error);
      }
    },
  },
};
</script>

<template>
  <div class="gl-border-t gl-mt-5 work-item-notes">
    <work-item-notes-activity-header
      :sort-order="sortOrder"
      :disable-activity-filter-sort="disableActivityFilterSort"
      :work-item-type="workItemType"
      :discussion-filter="discussionFilter"
      :use-h2="useH2"
      @changeSort="changeNotesSortOrder"
      @changeFilter="filterDiscussions"
    />
    <div v-if="initialLoading" class="gl-mt-5">
      <gl-skeleton-loader
        v-for="index in $options.loader.repeat"
        :key="index"
        :width="$options.loader.width"
        :height="$options.loader.height"
        preserve-aspect-ratio="xMinYMax meet"
      >
        <circle cx="20" cy="20" r="16" />
        <rect width="500" x="45" y="15" height="10" rx="4" />
      </gl-skeleton-loader>
    </div>
    <div v-else class="issuable-discussion gl-mb-5 gl-clearfix!">
      <template v-if="!initialLoading">
        <div v-if="formAtTop && !commentsDisabled" class="js-comment-form">
          <ul class="notes notes-form timeline">
            <work-item-add-note
              v-bind="workItemCommentFormProps"
              :key="addNoteKey"
              @cancelEditing="updateKey"
              @error="$emit('error', $event)"
            />
          </ul>
        </div>
        <ul class="notes main-notes-list timeline">
          <template v-for="discussion in notesArray">
            <system-note
              v-if="isSystemNote(discussion)"
              :key="discussion.notes.nodes[0].id"
              :note="discussion.notes.nodes[0]"
            />
            <template v-else>
              <work-item-discussion
                :key="getDiscussionKey(discussion)"
                :discussion="discussion.notes.nodes"
                :full-path="fullPath"
                :work-item-id="workItemId"
                :work-item-iid="workItemIid"
                :work-item-type="workItemType"
                :is-modal="isModal"
                :autocomplete-data-sources="autocompleteDataSources"
                :markdown-preview-path="markdownPreviewPath"
                :assignees="assignees"
                :can-set-work-item-metadata="canSetWorkItemMetadata"
                :is-discussion-locked="isDiscussionLocked"
                :is-work-item-confidential="isWorkItemConfidential"
                @deleteNote="showDeleteNoteModal($event, discussion)"
                @reportAbuse="reportAbuse(true, $event)"
                @error="$emit('error', $event)"
              />
            </template>
          </template>

          <work-item-history-only-filter-note
            v-if="commentsDisabled"
            @changeFilter="filterDiscussions"
          />
        </ul>
        <div v-if="!formAtTop && !commentsDisabled" class="js-comment-form">
          <ul class="notes notes-form timeline">
            <work-item-add-note
              v-bind="workItemCommentFormProps"
              :key="addNoteKey"
              @cancelEditing="updateKey"
              @error="$emit('error', $event)"
            />
          </ul>
        </div>
      </template>

      <template v-if="isLoadingMore">
        <gl-skeleton-loader
          v-for="index in $options.loader.repeat"
          :key="index"
          :width="$options.loader.width"
          :height="$options.loader.height"
          preserve-aspect-ratio="xMinYMax meet"
        >
          <circle cx="20" cy="20" r="16" />
          <rect width="500" x="45" y="15" height="10" rx="4" />
        </gl-skeleton-loader>
      </template>
    </div>
    <gl-modal
      ref="deleteNoteModal"
      modal-id="delete-note-modal"
      :title="__('Delete comment?')"
      :ok-title="__('Delete comment')"
      ok-variant="danger"
      size="sm"
      @primary="deleteNote"
      @canceled="cancelDeletingNote"
    >
      {{ __('Are you sure you want to delete this comment?') }}
    </gl-modal>
  </div>
</template>
