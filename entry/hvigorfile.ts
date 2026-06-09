import { hapTasks } from '@ohos/hvigor-ohos-plugin';

const path = require('path');
const { normalizeHapZip } = require('../hvigor/normalize-hap-zip.js');

const normalizeUnsignedHapBeforeSign = {
  pluginId: 'normalize-unsigned-hap-before-sign',
  apply(node) {
    const signTask = node.getTaskByName('default@SignHap');
    if (!signTask) {
      return;
    }

    signTask.beforeRun(() => {
      normalizeHapZip(path.resolve(node.getNodePath(), 'build/default/outputs/default/entry-default-unsigned.hap'));
    });
  }
};

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [normalizeUnsignedHapBeforeSign] /* Custom plugin to extend the functionality of Hvigor. */
}
