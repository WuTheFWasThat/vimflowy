
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

export type TextProperties = {
  bold?: boolean,
  italic?: boolean,
  underline?: boolean,
  strikethrough?: boolean,
};

export type Line = Array<Char>;
export type SerializedLine = {
  text: string,
  bold?: boolean,
  italic?: boolean,
  underline?: boolean,
  strikethrough?: boolean,
  collapsed?: boolean,
};

export type Row = number;
export type Col = number;
export type SerializedPath = Array<Row>;

export type MacroMap = {[key: string]: string};

