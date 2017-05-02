// TODO: enum for export mimetypes/extensions

// keyboard key
export type Key = string;

export type Macro = Array<Key>;
export type MacroMap = {[key: string]: Macro};

export type CursorOptions = {
  // means whether we're on the column or past it.
  // generally true when in insert mode but not in normal mode
  // effectively decides whether we can go past last column or not
  pastEnd?: boolean,

  // whether we consider the end of a word to be after the last letter
  // is true in normal mode (for de), false in visual (for vex)
  pastEndWord?: boolean,
};

export type Char = string;
export type Chars = Array<Char>;
export type Line = Chars;
export type SerializedLine = {
  text: string,
  collapsed?: boolean,
  plugins?: any,
};
export type SerializedBlock = {
  text: string,
  collapsed?: boolean,
  id?: Row,
  plugins?: any,
  children?: Array<SerializedBlock>
} | { clone: Row } | string;

export type Row = number;
export type Col = number;
export type SerializedPath = Array<Row>;

export type ModeId = string;
