<script>
import { isEmpty } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { STATUS_ALL, STATUS_CLOSED, STATUS_OPEN, STATUS_MERGED } from '~/issues/constants';
import { fetchPolicies } from '~/lib/graphql';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import { scrollUp } from '~/lib/utils/scroll_utils';
import { getParameterByName } from '~/lib/utils/url_utility';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import { DEFAULT_PAGE_SIZE, mergeRequestListTabs } from '~/vue_shared/issuable/list/constants';
import {
  convertToApiParams,
  convertToSearchQuery,
  convertToUrlParams,
  getFilterTokens,
  getInitialPageParams,
  getSortKey,
  getSortOptions,
  isSortKey,
} from '~/issues/list/utils';
import {
  CREATED_DESC,
  PARAM_FIRST_PAGE_SIZE,
  PARAM_LAST_PAGE_SIZE,
  PARAM_PAGE_AFTER,
  PARAM_PAGE_BEFORE,
  PARAM_STATE,
  UPDATED_DESC,
  urlSortParams,
} from '~/issues/list/constants';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import setSortPreferenceMutation from '~/issues/list/queries/set_sort_preference.mutation.graphql';
import { i18n } from '../constants';
import getMergeRequestsQuery from '../queries/get_merge_requests.query.graphql';
import getMergeRequestsCountsQuery from '../queries/get_merge_requests_counts.query.graphql';
import MergeRequestStatistics from './merge_request_statistics.vue';

export default {
  i18n,
  mergeRequestListTabs,
  components: {
    IssuableList,
    CiIcon,
    MergeRequestStatistics,
  },
  inject: [
    'fullPath',
    'hasAnyMergeRequests',
    'initialSort',
    'isPublicVisibilityRestricted',
    'isSignedIn',
  ],
  data() {
    return {
      filterTokens: [],
      mergeRequests: [],
      mergeRequestCounts: {},
      mergeRequestsError: null,
      pageInfo: {},
      pageParams: {},
      sortKey: CREATED_DESC,
      state: STATUS_OPEN,
      pageSize: DEFAULT_PAGE_SIZE,
    };
  },
  apollo: {
    mergeRequests: {
      query: getMergeRequestsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.project.mergeRequests.nodes ?? [];
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      nextFetchPolicy: fetchPolicies.CACHE_FIRST,
      notifyOnNetworkStatusChange: true,
      result({ data }) {
        if (!data) {
          return;
        }
        this.pageInfo = data.project.mergeRequests.pageInfo ?? {};
      },
      error(error) {
        this.mergeRequestsError = this.$options.i18n.errorFetchingMergeRequests;
        Sentry.captureException(error);
      },
      skip() {
        return !this.hasAnyMergeRequests || isEmpty(this.pageParams);
      },
    },
    mergeRequestCounts: {
      query: getMergeRequestsCountsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.project ?? {};
      },
      error(error) {
        this.mergeRequestsError = this.$options.i18n.errorFetchingCounts;
        Sentry.captureException(error);
      },
      skip() {
        return !this.hasAnyMergeRequests || isEmpty(this.pageParams);
      },
    },
  },
  computed: {
    queryVariables() {
      return {
        fullPath: this.fullPath,
        hideUsers: this.isPublicVisibilityRestricted && !this.isSignedIn,
        isSignedIn: this.isSignedIn,
        sort: this.sortKey,
        state: this.state,
        ...this.pageParams,
        ...this.apiFilterParams,
        search: this.searchQuery,
      };
    },
    hasSearch() {
      return Boolean(
        this.searchQuery ||
          Object.keys(this.urlFilterParams).length ||
          this.pageParams.afterCursor ||
          this.pageParams.beforeCursor,
      );
    },
    apiFilterParams() {
      return convertToApiParams(this.filterTokens);
    },
    urlFilterParams() {
      return convertToUrlParams(this.filterTokens);
    },
    searchQuery() {
      return convertToSearchQuery(this.filterTokens);
    },
    searchTokens() {
      return [];
    },
    showPaginationControls() {
      return (
        this.mergeRequests.length > 0 &&
        (this.pageInfo.hasNextPage || this.pageInfo.hasPreviousPage)
      );
    },
    sortOptions() {
      return getSortOptions({ hasManualSort: false });
    },
    tabCounts() {
      const {
        openedMergeRequests,
        closedMergeRequests,
        mergedMergeRequests,
        allMergeRequests,
      } = this.mergeRequestCounts;
      return {
        [STATUS_OPEN]: openedMergeRequests?.count,
        [STATUS_MERGED]: mergedMergeRequests?.count,
        [STATUS_CLOSED]: closedMergeRequests?.count,
        [STATUS_ALL]: allMergeRequests?.count,
      };
    },
    urlParams() {
      return {
        sort: urlSortParams[this.sortKey],
        state: this.state,
        ...this.urlFilterParams,
        first_page_size: this.pageParams.firstPageSize,
        last_page_size: this.pageParams.lastPageSize,
        page_after: this.pageParams.afterCursor ?? undefined,
        page_before: this.pageParams.beforeCursor ?? undefined,
      };
    },
    isLoading() {
      return (
        this.$apollo.queries.mergeRequests.loading &&
        !this.$apollo.provider.clients.defaultClient.readQuery({
          query: getMergeRequestsQuery,
          variables: this.queryVariables,
        })
      );
    },
  },
  created() {
    this.updateData(this.initialSort);
  },
  methods: {
    getStatus(mergeRequest) {
      if (mergeRequest.state === STATUS_CLOSED) {
        return this.$options.i18n.closed;
      }
      if (mergeRequest.state === STATUS_MERGED) {
        return this.$options.i18n.merged;
      }
      return undefined;
    },
    handleClickTab(state) {
      if (this.state === state) {
        return;
      }

      this.state = state;
      this.pageParams = getInitialPageParams(this.pageSize);

      this.$router.push({ query: this.urlParams });
    },
    handleNextPage() {
      this.pageParams = {
        afterCursor: this.pageInfo.endCursor,
        firstPageSize: this.pageSize,
      };
      scrollUp();

      this.$router.push({ query: this.urlParams });
    },
    handlePreviousPage() {
      this.pageParams = {
        beforeCursor: this.pageInfo.startCursor,
        lastPageSize: this.pageSize,
      };
      scrollUp();

      this.$router.push({ query: this.urlParams });
    },
    handleSort(sortKey) {
      if (this.sortKey === sortKey) {
        return;
      }

      this.sortKey = sortKey;
      this.pageParams = getInitialPageParams(this.pageSize);

      if (this.isSignedIn) {
        this.saveSortPreference(sortKey);
      }

      this.$router.push({ query: this.urlParams });
    },
    saveSortPreference(sortKey) {
      this.$apollo
        .mutate({
          mutation: setSortPreferenceMutation,
          variables: { input: { issuesSort: sortKey } },
        })
        .then(({ data }) => {
          if (data.userPreferencesUpdate.errors.length) {
            throw new Error(data.userPreferencesUpdate.errors);
          }
        })
        .catch((error) => {
          Sentry.captureException(error);
        });
    },
    handlePageSizeChange(newPageSize) {
      const pageParam = getParameterByName(PARAM_LAST_PAGE_SIZE) ? 'lastPageSize' : 'firstPageSize';
      this.pageParams[pageParam] = newPageSize;
      this.pageSize = newPageSize;
      scrollUp();

      this.$router.push({ query: this.urlParams });
    },
    updateData(sortValue) {
      const firstPageSize = getParameterByName(PARAM_FIRST_PAGE_SIZE);
      const lastPageSize = getParameterByName(PARAM_LAST_PAGE_SIZE);
      const state = getParameterByName(PARAM_STATE);

      const defaultSortKey = state === STATUS_CLOSED ? UPDATED_DESC : CREATED_DESC;
      const dashboardSortKey = getSortKey(sortValue);
      const graphQLSortKey = isSortKey(sortValue?.toUpperCase()) && sortValue.toUpperCase();

      const sortKey = dashboardSortKey || graphQLSortKey || defaultSortKey;

      const tokens = getFilterTokens(window.location.search);
      this.filterTokens = tokens;

      this.pageParams = getInitialPageParams(
        this.pageSize,
        isPositiveInteger(firstPageSize) ? parseInt(firstPageSize, 10) : undefined,
        isPositiveInteger(lastPageSize) ? parseInt(lastPageSize, 10) : undefined,
        getParameterByName(PARAM_PAGE_AFTER),
        getParameterByName(PARAM_PAGE_BEFORE),
      );
      this.sortKey = sortKey;
      this.state = state || STATUS_OPEN;
    },
  },
};
</script>

<template>
  <issuable-list
    v-if="hasAnyMergeRequests"
    :namespace="fullPath"
    recent-searches-storage-key="merge_requests"
    :search-tokens="searchTokens"
    :initial-filter-value="filterTokens"
    :sort-options="sortOptions"
    :initial-sort-by="sortKey"
    :issuables="mergeRequests"
    :error="mergeRequestsError"
    :tabs="$options.mergeRequestListTabs"
    :current-tab="state"
    :tab-counts="tabCounts"
    :issuables-loading="isLoading"
    :show-pagination-controls="showPaginationControls"
    :default-page-size="pageSize"
    sync-filter-and-sort
    use-keyset-pagination
    :has-next-page="pageInfo.hasNextPage"
    :has-previous-page="pageInfo.hasPreviousPage"
    @click-tab="handleClickTab"
    @next-page="handleNextPage"
    @previous-page="handlePreviousPage"
    @sort="handleSort"
    @page-size-change="handlePageSizeChange"
  >
    <template #status="{ issuable = {} }">
      {{ getStatus(issuable) }}
    </template>

    <template #statistics="{ issuable = {} }">
      <merge-request-statistics :merge-request="issuable" />
    </template>

    <template #pipeline-status="{ issuable = {} }">
      <li
        v-if="issuable.headPipeline && issuable.headPipeline.detailedStatus"
        class="issuable-pipeline-status d-none d-sm-flex"
      >
        <ci-icon :status="issuable.headPipeline.detailedStatus" use-link show-tooltip />
      </li>
    </template>
  </issuable-list>
</template>
