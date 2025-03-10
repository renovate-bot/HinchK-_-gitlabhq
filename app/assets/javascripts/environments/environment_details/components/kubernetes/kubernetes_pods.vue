<script>
import { GlTab, GlLoadingIcon, GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  STATUS_RUNNING,
  STATUS_PENDING,
  STATUS_SUCCEEDED,
  STATUS_FAILED,
  STATUS_LABELS,
} from '~/kubernetes_dashboard/constants';
import { getAge } from '~/kubernetes_dashboard/helpers/k8s_integration_helper';
import WorkloadStats from '~/kubernetes_dashboard/components/workload_stats.vue';
import WorkloadTable from '~/kubernetes_dashboard/components/workload_table.vue';
import k8sPodsQuery from '~/environments/graphql/queries/k8s_pods.query.graphql';

export default {
  components: {
    GlTab,
    GlLoadingIcon,
    GlBadge,
    WorkloadStats,
    WorkloadTable,
  },
  apollo: {
    k8sPods: {
      query: k8sPodsQuery,
      variables() {
        return {
          configuration: this.configuration,
          namespace: this.namespace,
        };
      },

      update(data) {
        return (
          data?.k8sPods?.map((pod) => {
            return {
              name: pod.metadata?.name,
              namespace: pod.metadata?.namespace,
              status: pod.status.phase,
              age: getAge(pod.metadata?.creationTimestamp),
            };
          }) || []
        );
      },
      error(error) {
        this.error = error.message;
        this.$emit('cluster-error', this.error);
      },
      watchLoading(isLoading) {
        this.$emit('loading', isLoading);
      },
    },
  },
  props: {
    configuration: {
      required: true,
      type: Object,
    },
    namespace: {
      required: true,
      type: String,
    },
  },
  data() {
    return {
      error: '',
    };
  },
  computed: {
    podStats() {
      if (!this.k8sPods) return null;

      return [
        {
          value: this.countPodsByPhase(STATUS_RUNNING),
          title: STATUS_LABELS[STATUS_RUNNING],
        },
        {
          value: this.countPodsByPhase(STATUS_PENDING),
          title: STATUS_LABELS[STATUS_PENDING],
        },
        {
          value: this.countPodsByPhase(STATUS_SUCCEEDED),
          title: STATUS_LABELS[STATUS_SUCCEEDED],
        },
        {
          value: this.countPodsByPhase(STATUS_FAILED),
          title: STATUS_LABELS[STATUS_FAILED],
        },
      ];
    },
    loading() {
      return this.$apollo?.queries?.k8sPods?.loading;
    },
    podsCount() {
      return this.k8sPods?.length || 0;
    },
  },
  methods: {
    countPodsByPhase(phase) {
      const filteredPods = this.k8sPods?.filter((item) => item.status === phase) || [];

      const hasFailedState = Boolean(phase === STATUS_FAILED && filteredPods.length);
      this.$emit('update-failed-state', { pods: hasFailedState });

      return filteredPods.length;
    },
  },
  i18n: {
    podsTitle: s__('Environment|Pods'),
  },
  PAGE_SIZE: 10,
};
</script>
<template>
  <gl-tab>
    <template #title>
      {{ $options.i18n.podsTitle }}
      <gl-badge size="sm" class="gl-tab-counter-badge">{{ podsCount }}</gl-badge>
    </template>

    <gl-loading-icon v-if="loading" />

    <template v-else-if="!error">
      <workload-stats v-if="podStats" :stats="podStats" class="gl-mt-3" />
      <workload-table
        v-if="k8sPods"
        :items="k8sPods"
        :page-size="$options.PAGE_SIZE"
        :row-clickable="false"
        class="gl-mt-8"
      />
    </template>
  </gl-tab>
</template>
