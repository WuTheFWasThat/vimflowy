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

  // for movement, whether we should keep italic/bold state
  keepProperties?: boolean,
};

// a character is represented by an object:
// {
//   char: 'a'
//   bold: true
//   italic: false
//   ..
// }
// in the case where all properties are false, it may be simply the character (to save space)
export type Char = {
  char: string,
  bold?: boolean,
  italic?: boolean,
  underline?: boolean,
  strikethrough?: boolean,
};

export type TextProperties = {
  bold?: boolean,
  italic?: boolean,
  underline?: boolean,
  strikethrough?: boolean,
};

export type Line = Array<Char>;
export type SerializedLine = {
  text: string,
  bold?: string,
  italic?: string,
  underline?: string,
  strikethrough?: string,
  collapsed?: boolean,
  plugins?: any,
};
export type SerializedBlock = {
  text: string,
  bold?: string,
  italic?: string,
  underline?: string,
  strikethrough?: string,
  collapsed?: boolean,
  id?: Row,
  plugins?: any,
  children?: Array<SerializedBlock>
} | { clone: Row } | string;

export type Row = number;
export type Col = number;
export type SerializedPath = Array<Row>;

export type ModeId = number;
