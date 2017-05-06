import { ModeId, SerializedBlock } from './types';
import KeyMappings from './keyMappings';

// TODO: key mappings
// TODO: starting mode
// TODO: starting text (i.e. constants.default_data)

export type ConfigType = 'vim' | 'workflowy';

type Config = {
  type: ConfigType;
  defaultMode: ModeId;
  defaultData: Array<SerializedBlock>;
  // NOTE: can be mutated when there's a mode registered
  defaultMappings: KeyMappings;
};
export default Config;
