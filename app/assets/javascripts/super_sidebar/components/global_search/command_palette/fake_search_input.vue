<script>
import { COMMON_HANDLES, PATH_HANDLE, SEARCH_SCOPE_PLACEHOLDER } from './constants';

export default {
  name: 'FakeSearchInput',
  props: {
    userInput: {
      type: String,
      required: true,
    },
    scope: {
      type: String,
      required: true,
      validator: (value) => [...COMMON_HANDLES, PATH_HANDLE].includes(value),
    },
  },
  computed: {
    placeholder() {
      return SEARCH_SCOPE_PLACEHOLDER[this.scope];
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-pointer-events-none fake-input">
    <span class="gl-opacity-0" data-testid="search-scope">{{ scope }}&nbsp;</span>
    <span
      v-if="!userInput"
      data-testid="search-scope-placeholder"
      class="gl-text-gray-500 gl-pointer-events-none"
      >{{ placeholder }}</span
    >
  </div>
</template>

<style scoped>
.fake-input {
  top: 14px;
  left: 39px;
}
</style>
