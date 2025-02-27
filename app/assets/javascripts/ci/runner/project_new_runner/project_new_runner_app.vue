<script>
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import { visitUrl, setUrlParams } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import RegistrationCompatibilityAlert from '~/ci/runner/components/registration/registration_compatibility_alert.vue';
import RunnerGoogleCloudOption from '~/ci/runner/components/runner_google_cloud_option.vue';
import RunnerPlatformsRadioGroup from '~/ci/runner/components/runner_platforms_radio_group.vue';
import RunnerCreateForm from '~/ci/runner/components/runner_create_form.vue';
import {
  DEFAULT_PLATFORM,
  PARAM_KEY_PLATFORM,
  GOOGLE_CLOUD_PLATFORM,
  PROJECT_TYPE,
} from '../constants';
import { captureException } from '../sentry_utils';
import { saveAlertToLocalStorage } from '../local_storage_alert/save_alert_to_local_storage';

export default {
  name: 'ProjectNewRunnerApp',
  components: {
    RegistrationCompatibilityAlert,
    RunnerGoogleCloudOption,
    RunnerPlatformsRadioGroup,
    RunnerCreateForm,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    projectId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      platform: DEFAULT_PLATFORM,
    };
  },
  computed: {
    googleCloudProvisioningEnabled() {
      return this.glFeatures.googleCloudSupportFeatureFlag;
    },
  },
  methods: {
    onSaved(runner) {
      const params = { [PARAM_KEY_PLATFORM]: this.platform };
      const ephemeralRegisterUrl = setUrlParams(params, runner.ephemeralRegisterUrl);

      saveAlertToLocalStorage({
        message: s__('Runners|Runner created.'),
        variant: VARIANT_SUCCESS,
      });
      visitUrl(ephemeralRegisterUrl);
    },
    onError(error, isValidationError = false) {
      if (isValidationError) {
        captureException({ error, component: this.$options.name });
      }
      createAlert({ message: error.message });
    },
  },
  PROJECT_TYPE,
  GOOGLE_CLOUD_PLATFORM,
};
</script>

<template>
  <div>
    <h1 class="gl-font-size-h2">{{ s__('Runners|New project runner') }}</h1>

    <registration-compatibility-alert :alert-key="projectId" />

    <p>
      {{
        s__(
          'Runners|Create a project runner to generate a command that registers the runner with all its configurations.',
        )
      }}
    </p>

    <hr aria-hidden="true" />

    <h2 class="gl-font-size-h2 gl-my-5">
      {{ s__('Runners|Platform') }}
    </h2>

    <runner-platforms-radio-group v-model="platform">
      <template v-if="googleCloudProvisioningEnabled" #cloud-options>
        <runner-google-cloud-option v-model="platform" />
      </template>
    </runner-platforms-radio-group>

    <hr aria-hidden="true" />

    <runner-create-form
      :runner-type="$options.PROJECT_TYPE"
      :project-id="projectId"
      @saved="onSaved"
      @error="onError"
    />
  </div>
</template>
