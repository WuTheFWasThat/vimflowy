export type CharInfo = {
  highlight: boolean,
  cursor: boolean,
  renderOptions: {
    divType?: string,
    classes: {[key: string]: boolean},
    href?: string,
    onClick?: null | (() => void),
  },
};

export type Token = {
  // index in the original text
  index: number,
  // length in the original text
  length: number,
  text: string,
  info: Array<CharInfo>,
};

export function SplitToken(token: Token, split_index: number): [Token, Token] {
  return [
    {
      index: token.index,
      length: split_index,
      text: token.text.slice(0, split_index),
      info: token.info.slice(0, split_index),
    },
    {
      index: token.index + split_index,
      length: token.length - split_index,
      text: token.text.slice(split_index),
      info: token.info.slice(split_index),
    }
  ];
}

export type EmitFn<T> = (output: T) => void;
export type ScannerFn<A, B> = (input: A, emit: EmitFn<B>) => void;

export class Scanner<A, B> {
  public fn: ScannerFn<A, B>;
  constructor(fn: ScannerFn<A, B>) {
    this.fn = fn;
  }

  public transduce(input: A): Array<B> {
    const results: Array<B> = [];
    this.fn(input, (output: B) => {
      results.push(output);
    });
    return results;
  }

  public then<C>(other: Scanner<B, C>): Scanner<A, C> {
    return new Scanner<A, C>((a: A) => {
      const results: Array<C> = [];
      this.transduce(a).forEach((b) => {
        results.push(...other.transduce(b));
      });
      return results;
    });
  }
}

// a scanner that sometimes doesn't give the output type
export type PartialScannerFn<A, B> = (
  input: A, emitA: EmitFn<A>, emitB: EmitFn<B>) => void;

export class PartialScanner<A, B> extends Scanner<A, A | B> {
  public partial_fn: PartialScannerFn<A, B>;

  public static trivial<A, B>() {
    return new PartialScanner<A, B>((input: A, emitA: EmitFn<A>) => emitA(input));
  }

  constructor(fn: PartialScannerFn<A, B>) {
    super((input: A, emit: EmitFn<A | B>) => {
      fn(input, emit, emit);
    });
    this.partial_fn = fn;
  }

  public chain(other: PartialScanner<A, B>): PartialScanner<A, B> {
    return new PartialScanner<A, B>((
      input: A, emitA: EmitFn<A>, emitB: EmitFn<B>
    ) => {
      this.partial_fn(input, (output: A) => {
        other.partial_fn(output, emitA, emitB);
      }, emitB);
    });
  }

  public finish(other: Scanner<A, B>): Scanner<A, B> {
    return new Scanner<A, B>((input: A, emit: EmitFn<B>) => {
      this.partial_fn(input, (output: A) => {
        other.fn(output, emit);
      }, emit);
    });
  }
}

export type Tokenizer<T> = Scanner<Token, T>;
export type TokenizerFn<T> = ScannerFn<Token, T>;
export type PartialTokenizer<T> = PartialScanner<Token, T>;
export type PartialTokenizerFn<T> = PartialScannerFn<Token, T>;

// captures first group of regex
export function RegexTokenizerSplitter<T>(
  regex: RegExp, tryHandleMatch: PartialTokenizerFn<T>
): PartialTokenizer<T> {
  return new PartialScanner<Token, T>((
    token: Token, emitToken: EmitFn<Token>, emit: EmitFn<T>
  ) => {
    let match = regex.exec(token.text);
    while (match) {
      // index of match, plus index of group in match
      let index = match.index + match[0].indexOf(match[1]);

      if (index > 0) {
        let filler_token;
        [filler_token, token] = SplitToken(token, index);
        emitToken(filler_token);
      }

      let matched_token;
      [matched_token, token] = SplitToken(token, match[1].length);
      tryHandleMatch(matched_token, emitToken, emit);

      match = regex.exec(token.text);
    }

    // leftover
    if (token.text.length) {
      emitToken(token);
    }
  });
};
