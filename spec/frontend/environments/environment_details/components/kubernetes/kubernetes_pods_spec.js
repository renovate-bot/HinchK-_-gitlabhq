import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon, GlTab } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import KubernetesPods from '~/environments/environment_details/components/kubernetes/kubernetes_pods.vue';
import WorkloadStats from '~/kubernetes_dashboard/components/workload_stats.vue';
import WorkloadTable from '~/kubernetes_dashboard/components/workload_table.vue';
import { useFakeDate } from 'helpers/fake_date';
import { mockKasTunnelUrl } from '../../../mock_data';
import { k8sPodsMock, k8sPodsStatsData, k8sPodsTableData } from '../../../graphql/mock_data';

Vue.use(VueApollo);

describe('~/environments/environment_details/components/kubernetes/kubernetes_pods.vue', () => {
  let wrapper;

  const namespace = 'my-kubernetes-namespace';
  const configuration = {
    basePath: mockKasTunnelUrl,
    baseOptions: {
      headers: { 'GitLab-Agent-Id': '1' },
    },
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTab = () => wrapper.findComponent(GlTab);
  const findWorkloadStats = () => wrapper.findComponent(WorkloadStats);
  const findWorkloadTable = () => wrapper.findComponent(WorkloadTable);

  const createApolloProvider = () => {
    const mockResolvers = {
      Query: {
        k8sPods: jest.fn().mockReturnValue(k8sPodsMock),
      },
    };

    return createMockApollo([], mockResolvers);
  };

  const createWrapper = (apolloProvider = createApolloProvider()) => {
    wrapper = shallowMount(KubernetesPods, {
      propsData: { namespace, configuration },
      apolloProvider,
      stubs: {
        GlTab,
      },
    });
  };

  describe('mounted', () => {
    it('renders pods tab', () => {
      createWrapper();

      expect(findTab().text()).toMatchInterpolatedText('Pods 0');
    });

    it('shows the loading icon', () => {
      createWrapper();

      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('emits loading state', async () => {
      createWrapper();
      expect(wrapper.emitted('loading')[0]).toEqual([true]);

      await waitForPromises();
      expect(wrapper.emitted('loading')[1]).toEqual([false]);
    });

    it('hides the loading icon when the list of pods loaded', async () => {
      createWrapper();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when gets pods data', () => {
    useFakeDate(2023, 10, 23, 10, 10);

    it('renders workload stats with the correct data', async () => {
      createWrapper();
      await waitForPromises();

      expect(findWorkloadStats().props('stats')).toEqual(k8sPodsStatsData);
    });

    it('renders workload table with the correct data', async () => {
      createWrapper();
      await waitForPromises();

      expect(findWorkloadTable().props('items')).toMatchObject(k8sPodsTableData);
    });

    it('emits a update-failed-state event for each pod', async () => {
      createWrapper();
      await waitForPromises();

      expect(wrapper.emitted('update-failed-state')).toHaveLength(4);
      expect(wrapper.emitted('update-failed-state')).toEqual([
        [{ pods: false }],
        [{ pods: false }],
        [{ pods: false }],
        [{ pods: true }],
      ]);
    });
  });

  describe('when gets an error from the cluster_client API', () => {
    const error = new Error('Error from the cluster_client API');
    const createErroredApolloProvider = () => {
      const mockResolvers = {
        Query: {
          k8sPods: jest.fn().mockRejectedValueOnce(error),
        },
      };

      return createMockApollo([], mockResolvers);
    };

    beforeEach(async () => {
      createWrapper(createErroredApolloProvider());
      await waitForPromises();
    });

    it("doesn't show pods stats", () => {
      expect(findWorkloadStats().exists()).toBe(false);
    });

    it("doesn't show pods table", () => {
      expect(findWorkloadTable().exists()).toBe(false);
    });

    it('emits an error message', () => {
      expect(wrapper.emitted('cluster-error')).toMatchObject([[error.message]]);
    });
  });
});
