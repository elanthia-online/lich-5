# Genie Expression Evaluators — Ruby Port Spec

Behaviour spec for the Ruby port (`lib/genie/eval.rb`, `math_eval.rb`, `math_calc.rb`,
`vb_conversions.rb`). **Parity target: Genie4 Remix v4.2.4** `Script/Eval.cs`, `Script/MathEval.cs`
(byte-identical to upstream's) and `Utility/Utility.cs`; line numbers marked **R** are Remix's.
Since WP8 (v0.21.0) both evaluators are literal ports: where this text and the code disagree, the
code (and Remix) wins.

> **Important correction:** three distinct evaluators exist, not two.
> - **`Eval`** (`Eval.cs`) — boolean/string. Used by `if`/`elseif`/`while` and `eval`/`waiteval`.
> - **`MathEval`** (`MathEval.cs`) — recursive-descent arithmetic. Used **only** by `evalmath`.
> - **`Utility.MathCalc`** (Utility.cs:883 R) — keyword-based. Used by **`math`** and **`counter`**.

---

## PART A — `Eval` (boolean/string)

> **WP8 (v0.21.0):** `lib/genie/eval.rb` is now a LITERAL port of Remix `Script/Eval.cs` (every
> method names the C# member it ports), checked with 0 diffs against genieoracle on the curated
> golden, the 38k-row corpus golden and the grammar / character-level fuzzers. Where this part
> and the code disagree, the code (and Eval.cs R) wins. Corrections found by the port are marked
> **WP8** below.

**Pipeline** (`EvalString` Eval.cs:45 R / `DoEval` Eval.cs:874 R): `ReplaceKeyWords` → `Parse` (builds `oSections`) →
`ParseQueue` → `GetStringResult` (for `eval`) or `GetBooleanResult` (for `if`/`while`).
`m_RegExpResultList` cleared at entry; populated by the `matchre` function for `$0..$n`.

### Tokenizer (`Parse` Eval.cs:153 R, `SectionEnqueue` Eval.cs:291 R)
`SEPARATORS = "!=<>,&|"`. Single-pass scanner → `Section{ sBlock, BlockType, bParsed }`.
`ParseType`: `Separator, Number, String, SectionStart, SectionEnd, Function, Negate`.
- Only `"` starts a string (single-quote disabled). Quoted content strips surrounding quotes if len>1.
- Consecutive separator chars coalesce → `==`, `!=`, `<=`, `>=`, `<>`, `&&`, `||` are single tokens.
- Numeric char = digit OR `.` OR leading `-` (when `bIgnoreNumber==false`) → `NumberType`.
- `(` → SectionStart, `)` → SectionEnd.
- Space/tab: splits token unless inside a `FunctionType` token (then sets `bIgnoreNumber` so barewords
  may contain spaces/digits, e.g. `dead man`).
- Anything else → `FunctionType`, `bIgnoreNumber=true`. **WP8:** a letter after a number FLUSHES the
  number section (`1x` = number `1` + word `x`, so `1x = 1` is "1"); `+`, `{`, `%` start a word (`+5`
  and `+ 5` are strings), so `(3 + 5) = 10` is "3".

`SectionEnqueue` post-processing (trim; drop empty):
- If `FunctionType`, lowercase switch: `eq→=`, `and→&&`, `or→||`, `not→!`(Negate), `true→1`, `false→0`.
  **Default:** if `|token|` NOT in the function list → reclassify as `StringType` (bareword → literal).
- `SeparatorType` token `!` → `NegateType`.

**Function list** (barewords in it stay callable): `instr, instring, contains, indexof, lastindexof,
match, startswith, endswith, replace, tolower, toupper, trim, len, length, substr, substring,
matchre, replacere, count, element, def, defined`. **WP8:** matched CASE-SENSITIVELY as
`"|" + token + "|"` against a string that lacks the closing `|` after `defined` (Eval.cs:285 R): `Len(`
and `defined(` are plain words (`defined(x)` evaluates to "defined").

### Keyword aliasing (`ReplaceKeyWords` Eval.cs:54 R, regex Eval.cs:92 R)
Applied only OUTSIDE double-quoted strings. Canonical list is exactly six:
`eq→=`, `and→&&`, `or→||`, `not→!`, `true→1`, `false→0`. **No `ne/ge/le/gt/lt` keywords.**
Remix (parity target): the regex is `RegexOptions.IgnoreCase | options` (Eval.cs:92 R) and the
match is lowercased before the switch (Eval.cs:102 R), so `AND`/`Or`/`NOT`/`TRUE`/`EQ` translate
like the lowercase forms (whole word, outside quotes only). Upstream 4.5.0.3 had the
`IgnoreCase & options` (= None) bug that made the pass lowercase-only; ours followed it until v0.11.0
(N03, flow oracle t41, eval golden rows).

### Precedence & comparisons (`ParseSection` Eval.cs:482 R)
Three ordered passes per parenthesized section → **comparisons > NOT > AND/OR**, each left-associative;
AND and OR are equal precedence (single pass, left-to-right).

`ParseCompare` (Eval.cs:644 R) — **numeric iff BOTH operands are `NumberType`**; else string. Numeric parse via
`StringToDouble` (returns **-1** on failure, en-US).

| Op | Numeric | String |
|---|---|---|
| `=` `==` | `d1==d2` | `String.Equals` (ordinal, **case-sensitive**) |
| `!=` `<>` | `d1!=d2` | negated equals |
| `>` `>=` `<` `<=` | usual | **always 0 (false)** for strings |
| `\|\|` | `(d1>0)\|\|(d2>0)` | 0 if either operand non-numeric |
| `&&` | `(d1>0)&&(d2>0)` | 0 if either operand non-numeric |

Only strictly-positive numbers are truthy in `&&`/`||`. `ParseCompare` swallows errors → leaves unparsed.

**WP8, the flat model:** nothing is ever removed from the section list. `ParseQueue` (Eval.cs:374-397 R)
recurses at `(`; at `)` it runs `ParseSection(start, j-1)` and returns; an unclosed `(` parses to the end
and then the enclosing range too (so its function is still called); a TOP-LEVEL `)` ends parsing (the
rest stays raw: `1 > 0) x` is "1"). `ParseSection` first calls the function two sections before its
start, then the three passes over UNPARSED sections only: comparisons (`&&`/`||` reset both sides;
any other separator, `,` included, becomes the comparer), `!` (flips the next number/string's TEXT,
keeping its TYPE), then `&&`/`||` (the left operand is not reset). A comparison missing an operand
leaves the other standing (`> 9` is true).

### Functions (`ParseFunction` Eval.cs:892 R) — ordinal/case-sensitive
| Function | Arity | Semantics | Type |
|---|---|---|---|
| `instr`/`instring`/`contains` | 2 | `a.Contains(b)` | Num |
| `indexof` | 2 | `a.IndexOf(b)+1` (0 if none) | Num |
| `lastindexof` | 2 | `a.LastIndexOf(b)+1` | Num |
| `match` | 2 | `String.Equals(a,b)` | Num |
| `startswith`/`endswith` | 2 | prefix/suffix test | Num |
| `replace` | 3 | literal replace-all | Str |
| `tolower`/`toupper`/`trim` | 1 | as named | Str |
| `len`/`length` | 1 | `a.Length` | Num |
| `substr`/`substring` | 2\|3 | see below | Str |
| `matchre` | 2 | `Regex.Match(a,b)`; fills `$0..$n` on success | Num |
| `replacere` | 3 | `Regex.Replace(a,b,c)` | Str |
| `count` | 2 | non-overlapping occurrences (step by match len) | Num |
| `element` | 2 | strip `()`, split on `\|`, 0-based index w/ clamp | Str |
| `def` | 1 | global var exists (`defined` is not a function, see above) | Num |

**WP8:** `BuildArgs` consumes EVERY unparsed string/number section of the call's range first; a wrong
argument count then leaves the function section untouched (a function section is never a result), so a
wrong-arity call is a silent no-op that swallows its arguments (`matchre(a, b, c)` never compiles `b`).
.NET exceptions escape (G46: the interpreter prints the message and stops the script): `substr`'s VB
`ToInteger` and `String.Substring` range checks, `element`'s `int.Parse`, `replace` with an empty old
value, an invalid `matchre`/`replacere` pattern (its message is "Invalid pattern '<p>': <reason>" with
Onigmo's reason, not .NET's RegexParseException text). `count(x, "")` loops forever in Remix: ours stops
the script (decided). Positions count UTF-16 code units; `toupper`/`tolower` map one character to one.
Both evaluators read invalid UTF-8 (and raw bytes) as the decoded .NET text, each bad sequence U+FFFD.

**WP8-r1:** Parse's number characters are `Information.IsNumeric(ch)` (Eval.cs:205 R): 0-9 and the
infinity sign U+221E (what `evalmath r 1/0` stores), plus `.` and `-`. The comparison's
`Utility.StringToDouble` reads `[+-]?` U+221E (white space trimmed) as an infinity; any other text
around the sign is -1 (`--`, `1`, a trailing `-`, `.`).

**WP8-r2:** `double.Parse` skips only .NET's number white (TAB..CR, space) around a NUMBER and allows
trailing NULs after it (`"\0 5"` = -1, `"5 \0"` = 5); the NaN / U+221E symbols are matched on the
`String.Trim()`med text (char.IsWhiteSpace: U+00A0, U+3000 ... but never NUL). A pause / delay / wait
/ matchwait time that `DateTime.AddMilliseconds` rejects (an infinity, > 315,537,897,599,999 ms, or a
result past year 9999) stops the script with the .NET message (G46 class).

`substr(s,start,length)`: if `length<0`: if `start+length>=0` then `start+=length; length=|length|`
else `start=0; length=orig_start`. Clamp `start<0→0`, `length<0→0`. If `start+length>s.Length`
→ substring to end, else fixed length. `substr(s,start)`: substring-to-end if `0<=start<=len`
else no-op. Integer coercion = VB `ToInteger` = **banker's rounding**.

### Truthiness (`IsSectionTrue` Eval.cs:1279 R, `GetBooleanResult` Eval.cs:425 R)
`"0"`→false, `"1"`→true, else `NumberType` && `int.Parse>0`→true (**WP8:** `09` is true; a fraction,
`+5` or an Int32 overflow is false), else (**any string**)→false.
Bare non-empty string in `if` is **false**. Empty/unparseable expr → `false`. **WP8:** `GetBooleanResult`
is true when ANY unparsed number section is true (`0 1` is true); `GetStringResult` takes sections
while its result is still EMPTY, i.e. the first NON-EMPTY unparsed Number/String text (`"" x` is "x").

### Edge cases
Unbalanced parens tolerated (no throw). No variable lookup inside `Eval` — substitution happens before.
Quoted `"5"` is a String, so `"5" = 5` is a string compare (false).

---

## PART B — `MathEval` (arithmetic, `evalmath` only)

> **WP8 (v0.21.0):** `lib/genie/math_eval.rb` is a LITERAL port (calc_scan's state table, the
> level0..level6 descent, VB IsNumeric/ToDouble/ToInteger/ToLong in `VbConversions`). Corrections:
> `IsNumeric` is VB's (`1,000`, `$5`, `(5)` = -5, `5-`, `2 +`, `&H10`, `NaN`, `1e400` convert directly);
> level0 evaluates the FIRST expression and ignores the leftover tokens (`1+1 = 2` is 2, `3!!` is 6);
> `&` and `(` after an operand are LEVEL5 operators with no calc_op case (`2 & 3`, `2(3)` are 0).
> **WP8-r1:** `^` is Math.Pow, so `neg(1/0) ^ 0.5` is +Infinity and `neg(1/0) ^ -0.5` is +0 (a FINITE
> negative base with a fractional exponent is NaN); `%` with an infinite dividend is NaN whatever the
> divisor (also `#math ... mod`).

`Evaluate` (MathEval.cs:141 R) — if whole string `IsNumeric`, return directly; else `calc_scan` → `level0`.
Errors → `InvalidCastException("Invalid expression: …")`; `evalmath` then sets target var to `"0"`.
All arithmetic is IEEE `double`; culture forced en-US by callers.

### Operators (`init_operators` MathEval.cs:69 R) — `+`/`-` registered twice (binary L1 + unary L4)
| Token | Level | Role |
|---|---|---|
| `+` `-` | L1 | binary add/sub |
| `*` `/` `\` `%` | L2 | mul / float-div / **int-div** / mod |
| `^` | L3 | power (**left-assoc!** `2^3^2==64`) |
| `+` `-` | L4 | unary (≤1 prefix sign) |
| `!` | L5 | factorial (postfix, applied once) |
| `&` | L5 | registered but no-op → 0 |

Precedence low→high: `+ -` < `* / \ %` < `^` < unary `+ -` < `!` < atoms/parens/functions.

### Grammar
```
level0 := level1                             # the FIRST expression; leftover tokens are ignored
level1 := level2 ( ("+"|"-")@L1 level2 )*
level2 := level3 ( ("*"|"/"|"\"|"%")@L2 level3 )*
level3 := level4 ( "^"@L3 level4 )*          # left-assoc
level4 := ("+"|"-")@L4 ? level5              # unary, ≤1
level5 := level6 "!"?                        # factorial, once
level6 := "(" level1 ")" | IDENT | FUNC "(" args ")" | NUMBER
```

### `calc_op` operand order (MathEval.cs:157 R)
`^`=`Pow(op1,op2)`; `+`(L1)=`op2+op1`; `-`(L1)=`op1-op2`; `*`=`op2*op1`; `/`=`op1/op2` (div0→Inf/NaN);
`\`=`ToLong(op1)/ToLong(op2)` integer division (banker's round to Int64); `%`=`op1%op2`;
unary `-`=`-op1`, unary `+`=`op1`; `!`=factorial (`0!=1`, negatives→1, arg truncated via ToInteger).

### Functions (`calc_function` MathEval.cs:242 R, `m_funcs` MathEval.cs:63 R)
`sin cos tan arcsin arccos arctan` (radians), `sqrt floor ceiling abs neg pos`,
`log`=**log10** (not natural!), `log10`, `ln`=natural log, `round(x[,n])` banker's rounding,
`max/min` (fold over args). Constants: `e`→Math.E, `pi`→Math.PI (case-insensitive); other ident → 0.

`calc_scan` (MathEval.cs:418 R) is a table-driven DFA. **WP8 correction:** ALPHA/DIGITS are searched with
`IndexOf(..) > 0`, so `_` and `#` are PUNCTUATION (`_x`, `#5` throw); a digit ENDS an identifier
(`log10(1000)` is `log` then 10 and throws; `pi2` is pi); a letter after a number turns the whole run
into one identifier (`5abc` is 0). The port keeps the state table verbatim.

---

## PART C — `math` / `counter` (`Utility.MathCalc`, Utility.cs:883 R) — NOT MathEval

`math <var> <expr>` → `DoMath(var, expr)`; `counter <expr>` → `DoMath("c", expr)` (fixed var `c`).
`DoMath` (Script.cs:3293-3308 R) reads the current value via `StringToDouble` (missing → 0, non-numeric → -1), applies `MathCalc`, stores
`double.ToString()` back, fires `TriggerVariableChanged`. `math` bar-command variant uses **globals**;
script `math`/`counter` use **local** vars — same `MathCalc`. The `#math` command reads the current
global with `double.TryParse` instead (Command.cs:1033-1034 R): a failure (or no such variable) is **0**,
not -1 (`#var x abc` then `#math x add 1` = 1); a bad keyword (or no expression: `#math x`) echoes
`Invalid #math expression: <args>` and sets nothing (Command.cs:1044-1047 R).

`MathCalc(value, expr)`: `keyword`=first word, `n=StringToDouble(rest)` **clamped `n<0→0`**, then:

| Keyword | Op |
|---|---|
| `add` / `+` | `value+n` |
| `sub`/`substract`/`subtract` / `-` | `value-n` |
| `set` / `=` | `n` |
| `multiply` / `*` | `value*n` |
| `divide` / `/` | `value/n` if n≠0, else value unchanged (Remix Utility.cs:928 R; upstream gives Infinity) |
| `mod`/`modulus` / `%` | `value%n` (C# double %, `x%0`=NaN) if value≠0 else 0 (Utility.cs:932-946 R) |
| else | throw `"Invalid #MATH expression: <expr>"`. Script `math`/`counter` (DoMathCalc, Script.cs:3318-3333 R): PrintError `Invalid MATH expression: <expr>` + AbortOnScriptError; with a `scripterror` label the variable is set to 0 and the script jumps there, otherwise it stops. `#math`: echo `Invalid #math expression: <args>`, nothing set |

**Quirk to preserve:** the `n<0→0` clamp means `math x subtract -5` subtracts 0, not -5.

---

## Cross-cutting formatting/rounding (must reproduce)
- `StringToDouble`: en-US, returns **-1.0** on empty/nil/parse-failure (`#math`'s TryParse: 0).
- VB `ToInteger`/`ToLong`: **banker's rounding** (half-to-even) — affects `substr`, `round(x,n)`,
  factorial, `\` integer division.
- Every .NET number parse here (`StringToDouble`, VB `ToInteger`/`ToDouble`/`IsNumeric`) accepts a
  run of NULs after the whole number (`5 \0` = 5; `5\0 `, `\05`, `&H1F\0`, `NaN\0` fail:
  Number.TrailingZeros; genieoracle `s2d` / `tointmsg` / `math`).
- Result stringification = .NET `double.ToString()` "G" (en-US): integers print without `.0`;
  reproduce shortest round-trip formatting.
