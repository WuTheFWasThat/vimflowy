
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
export type SerializedPath = Array<Row>;

export type MacroMap = {[key: string]: string};

