/*
Represents user settings
Uses a datastore key which is agnostic to which document is being viewed
(i.e. /blah and /blah2 have the same settings)
*/

import DataStore, { DataSource } from './datastore';

// TODO: an enum for themes

type SettingsType = {
  theme: string;
  showKeyBindings: boolean;
  hotkeys: any; // TODO
  enabledPlugins: Array<string>,
};

type SettingType = keyof SettingsType;

const default_settings: SettingsType = {
  theme: 'default-theme',
  showKeyBindings: true,
  hotkeys: {},
  // TODO import these names from the plugins
  enabledPlugins: ['Marks', 'HTML', 'LaTeX', 'Text Formatting', 'Todo'],
};

type DocSettingsType = {
  dataSource: DataSource;
  firebaseId: string | null;
  firebaseApiKey: string | null;
  firebaseUserEmail: string | null;
  firebaseUserPassword: string | null;
};

type DocSettingType = keyof DocSettingsType;

const default_doc_settings: DocSettingsType = {
  dataSource: 'local',
  firebaseId: null,
  firebaseApiKey: null,
  firebaseUserEmail: null,
  firebaseUserPassword: null,
};

export default class Settings {
  private datastore: DataStore;

  constructor(datastore: DataStore) {
    this.datastore = datastore;
  }

  public async getSetting<S extends SettingType>(setting: S): Promise<SettingsType[S]> {
    return await this.datastore.getSetting(setting, default_settings[setting]);
  }

  public async setSetting<S extends SettingType>(setting: S, value: SettingsType[S]): Promise<void> {
    return await this.datastore.setSetting(setting, value);
  }

  public async getDocSetting<S extends DocSettingType>(setting: S): Promise<DocSettingsType[S]> {
    const defaultValue = default_doc_settings[setting];
    return await this.datastore.getDocSetting(setting, defaultValue);
  }

  public async setDocSetting<S extends DocSettingType>(setting: S, value: DocSettingsType[S]): Promise<void> {
    return await this.datastore.setDocSetting(setting, value);
  }
}
