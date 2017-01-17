import { ModeId, SerializedBlock } from './types';
import KeyMappings from './keyMappings';

// TODO: key mappings
// TODO: starting mode
// TODO: starting text (i.e. constants.default_data)

type Config = {
  defaultMode: ModeId;
  defaultData: Array<SerializedBlock>;
  // NOTE: can be mutated when there's a mode registered
  defaultMappings: KeyMappings;
};
export default Config;
