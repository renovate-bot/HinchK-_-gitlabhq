<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_USERS_SAVED_REPLY } from '~/graphql_shared/constants';
import CreateForm from '../components/form.vue';

export default {
  components: {
    GlLoadingIcon,
    CreateForm,
  },
  apollo: {
    savedReply: {
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      query() {
        return this.fetchSingleQuery;
      },
      variables() {
        return {
          id: convertToGraphQLId(TYPE_USERS_SAVED_REPLY, this.$route.params.id),
        };
      },
      update: (r) => r.object.savedReply,
      skip() {
        return !this.$route.params.id;
      },
      result({
        data: {
          object: { savedReply },
        },
      }) {
        if (!savedReply) {
          createAlert({ message: __('Unable to find comment template') });
          this.redirectToRoot();
        }
      },
    },
  },
  inject: ['fetchSingleQuery'],
  data() {
    return {
      savedReply: null,
    };
  },
  methods: {
    redirectToRoot() {
      this.$router.push({ path: '/' });
    },
  },
};
</script>

<template>
  <div>
    <h5 class="gl-mt-0 gl-font-lg">
      {{ __('Edit comment template') }}
    </h5>
    <gl-loading-icon v-if="$apollo.queries.savedReply.loading" size="lg" />
    <create-form
      v-else-if="savedReply"
      :id="savedReply.id"
      :name="savedReply.name"
      :content="savedReply.content"
      @saved="redirectToRoot"
    />
  </div>
</template>
