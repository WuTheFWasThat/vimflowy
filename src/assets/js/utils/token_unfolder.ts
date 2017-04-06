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

export function SliceToken(token: Token, start: number, end: number = 0): Token {
  if (end <= 0) {
    end = token.length + end;
  }
  return {
    index: token.index + start,
    length: end - start,
    text: token.text.slice(start, end),
    info: token.info.slice(start, end),
  };
}

export function SplitToken(token: Token, split_index: number): [Token, Token] {
  return [
    SliceToken(token, 0, split_index),
    SliceToken(token, split_index)
  ];
}

export type EmitFn<T> = (...output: Array<T>) => void;
export type UnfolderFn<A, B> = (input: A, emit: EmitFn<B>) => void;

export class Unfolder<A, B> {
  public fn: UnfolderFn<A, B>;
  constructor(fn: UnfolderFn<A, B>) {
    this.fn = fn;
  }

  public unfold(input: A): Array<B> {
    const results: Array<B> = [];
    this.fn(input, (...outputs: Array<B>) => {
      results.push(...outputs);
    });
    return results;
  }

  public then<C>(other: Unfolder<B, C>): Unfolder<A, C> {
    return new Unfolder<A, C>((a: A, emit: EmitFn<C>) => {
      this.unfold(a).forEach((b) => {
        emit(...other.unfold(b));
      });
    });
  }
}

export type Tokenizer<T> = Unfolder<Token, T>;
export type TokenizerFn<T> = UnfolderFn<Token, T>;

export type PartialUnfolderFn<A, B> = (input: A, emit: EmitFn<B>, wrapped: Unfolder<A, B>) => void;
export type PartialTokenizerFn<T> = PartialUnfolderFn<Token, T>;

export class PartialUnfolder<A, B> {
  public partial_fn: PartialUnfolderFn<A, B>;

  public static trivial<A, B>() {
    return new PartialUnfolder<A, B>((input: A, emit: EmitFn<B>, wrapped: Unfolder<A, B>) => {
      emit(...wrapped.unfold(input));
    });
  }

  constructor(fn: PartialUnfolderFn<A, B>) {
    this.partial_fn = fn;
  }

  public then(other: PartialUnfolder<A, B>): PartialUnfolder<A, B> {
    return new PartialUnfolder<A, B>((
      input: A, emit: EmitFn<B>, wrapped: Unfolder<A, B>
    ) => {
      this.partial_fn(
        input, emit,
        new Unfolder<A, B>((input2: A, emit2: EmitFn<B>) => {
          other.partial_fn(input2, emit2, wrapped);
        })
      );
    });
  }

  public finish(other: Unfolder<A, B>): Unfolder<A, B> {
    return new Unfolder<A, B>((input: A, emit: EmitFn<B>) => {
      this.partial_fn(input, emit, other);
    });
  }
}

export type PartialTokenizer<T> = PartialUnfolder<Token, T>;

// captures first group of regex and allows emitting based on the value
export function RegexTokenizerSplitter<T>(
  regex: RegExp, match_tokenizer: PartialTokenizerFn<T>,
): PartialTokenizer<T> {
  return new PartialUnfolder<Token, T>((
    token: Token, emit: EmitFn<T>, wrapped: Tokenizer<T>
  ) => {
    let match = regex.exec(token.text);
    while (match) {
      // index of match, plus index of group in match
      let index = match.index + match[0].indexOf(match[1]);

      if (index > 0) {
        let filler_token;
        [filler_token, token] = SplitToken(token, index);
        emit(...wrapped.unfold(filler_token));
      }

      let matched_token;
      [matched_token, token] = SplitToken(token, match[1].length);
      match_tokenizer(matched_token, emit, wrapped);

      match = regex.exec(token.text);
    }

    // leftover
    if (token.text.length) {
      emit(...wrapped.unfold(token));
    }
  });
};
