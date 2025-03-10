<script>
import { GlAvatar, GlBadge, GlButton, GlLink, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { formatDate, getTimeago } from '~/lib/utils/datetime_utility';
import { cleanLeadingSeparator } from '~/lib/utils/url_utility';
import { CI_RESOURCE_DETAILS_PAGE_NAME } from '../../router/constants';

export default {
  i18n: {
    components: s__('CiCatalog|Components:'),
    unreleased: s__('CiCatalog|Unreleased'),
    releasedMessage: s__('CiCatalog|Released %{timeAgo} by %{author}'),
  },
  components: {
    GlAvatar,
    GlBadge,
    GlButton,
    GlLink,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    resource: {
      type: Object,
      required: true,
    },
  },
  computed: {
    authorName() {
      return this.latestVersion.author.name;
    },
    authorUsername() {
      return this.latestVersion.author.username;
    },
    authorId() {
      return getIdFromGraphQLId(this.latestVersion.author.id);
    },
    authorProfileUrl() {
      return this.latestVersion.author.webUrl;
    },
    componentNames() {
      const components = this.resource.latestVersion?.components?.nodes;
      return components?.map((component) => component.name).join(', ') || null;
    },
    detailsPageHref() {
      return decodeURIComponent(this.detailsPageResolved.href);
    },
    detailsPageResolved() {
      return this.$router.resolve({
        name: CI_RESOURCE_DETAILS_PAGE_NAME,
        params: { id: this.resourceId },
      });
    },
    entityId() {
      return getIdFromGraphQLId(this.resource.id);
    },
    formattedDate() {
      return formatDate(this.latestVersion?.createdAt);
    },
    hasComponents() {
      return Boolean(this.componentNames);
    },
    hasReleasedVersion() {
      return Boolean(this.latestVersion?.createdAt);
    },
    latestVersion() {
      return this.resource?.latestVersion || {};
    },
    name() {
      return this.latestVersion?.name || this.$options.i18n.unreleased;
    },
    createdAt() {
      return getTimeago().format(this.latestVersion?.createdAt);
    },
    resourceId() {
      return cleanLeadingSeparator(this.resource.webPath);
    },
    starCount() {
      return this.resource?.starCount || 0;
    },
    starCountText() {
      return n__('Star', 'Stars', this.starCount);
    },
    webPath() {
      return cleanLeadingSeparator(this.resource?.webPath);
    },
    starsHref() {
      return this.resource.starrersPath;
    },
  },
  methods: {
    navigateToDetailsPage(e) {
      // Open link in a new tab if any of these modifier key is held down.
      if (e?.ctrlKey || e?.metaKey) {
        return;
      }

      // Override the <a> tag if no modifier key is held down to use Vue router and not
      // open a new tab.
      e.preventDefault();

      // Push to the decoded URL to avoid all the / being encoded
      this.$router.push({ path: decodeURIComponent(this.resourceId) });
    },
  },
};
</script>
<template>
  <li
    class="gl-display-flex gl-align-items-center gl-border-b-1 gl-border-gray-100 gl-border-b-solid gl-text-gray-500 gl-py-3"
    data-testid="catalog-resource-item"
  >
    <gl-avatar
      class="gl-mr-4"
      :entity-id="entityId"
      :entity-name="resource.name"
      shape="rect"
      :size="48"
      :src="resource.icon"
      @click="navigateToDetailsPage"
    />
    <div class="gl-display-flex gl-flex-direction-column gl-flex-grow-1">
      <span class="gl-font-sm gl-mb-1">{{ webPath }}</span>
      <div class="gl-display-flex gl-flex-wrap gl-gap-2 gl-mb-1">
        <gl-link
          class="gl-text-gray-900! gl-mr-1"
          :href="detailsPageHref"
          data-testid="ci-resource-link"
          @click="navigateToDetailsPage"
        >
          <b> {{ resource.name }}</b>
        </gl-link>
        <div class="gl-display-flex gl-flex-grow-1 gl-md-justify-content-space-between">
          <gl-badge size="sm" class="gl-h-5 gl-align-self-center">{{ name }}</gl-badge>
          <gl-button
            v-gl-tooltip.top
            data-testid="stats-favorites"
            class="gl-reset-color!"
            icon="star-o"
            :title="starCountText"
            :href="starsHref"
            size="small"
            variant="link"
          >
            {{ starCount }}
          </gl-button>
        </div>
      </div>
      <div
        class="gl-display-flex gl-flex-direction-column gl-md-flex-direction-row gl-justify-content-space-between gl-font-sm"
      >
        <div>
          <span class="gl-display-flex gl-flex-basis-two-thirds">{{ resource.description }}</span>
          <div
            v-if="hasComponents"
            data-testid="ci-resource-component-names"
            class="gl-font-sm gl-mt-1"
          >
            <span class="gl-font-weight-bold"> &#8226; {{ $options.i18n.components }} </span>
            <span class="gl-text-gray-900">{{ componentNames }}</span>
          </div>
        </div>
        <div class="gl-display-flex gl-justify-content-end">
          <span v-if="hasReleasedVersion">
            <gl-sprintf :message="$options.i18n.releasedMessage">
              <template #timeAgo>
                <span v-gl-tooltip.top :title="formattedDate">
                  {{ createdAt }}
                </span>
              </template>
              <template #author>
                <gl-link
                  :data-name="authorName"
                  :data-user-id="authorId"
                  :data-username="authorUsername"
                  data-testid="user-link"
                  :href="authorProfileUrl"
                  class="js-user-link"
                >
                  <span>{{ authorName }}</span>
                </gl-link>
              </template>
            </gl-sprintf>
          </span>
        </div>
      </div>
    </div>
  </li>
</template>
