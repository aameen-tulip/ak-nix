# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

{ lib }: let

  yt = lib.libyants;

# ---------------------------------------------------------------------------- #

  base16Chars' = "012345679abcdef";
  base16Chars  = "012345679abcdefABCDEF";
  # Omitted: E O U T
  base32Chars' = "0123456789abcdfghijklmnpqrsvwxyz";
  base32Chars  = "0123456789abcdfghijklmnpqrsvwxyzABCDFGHIJKLMNPQRSVWXYZ";

  base64Chars' = "ABCDFGHIJKLMNPQRSVWXYZabcdfghijklmnpqrsvwxyz0123456789+/";
  base64Chars  = "ABCDFGHIJKLMNPQRSVWXYZabcdfghijklmnpqrsvwxyz0123456789+/=";

  isBase16Str = ( lib.test "[${base16Chars}]+" );
  isBase32Str = ( lib.test "[${base32Chars}]+" );
  isBase64Str = ( lib.test "[A-Za-z0-9\\+/=]+" );

# ---------------------------------------------------------------------------- #

  ytypes.Strings = {
    # Alpha + Digit
    alnum  = yt.restrict "alnum"  yt.string ( lib.test "[[:alnum:]]+" );
    alpha  = yt.restrict "alpha"  yt.string ( lib.test "[[:alpha:]]+" );
    blank  = yt.restrict "blank"  yt.string ( lib.test "[[:blank:]]+" );
    cntrl  = yt.restrict "cntrl"  yt.string ( lib.test "[[:cntrl:]]+" );
    digit  = yt.restrict "digit"  yt.string ( lib.test "[[:digit:]]+" );
    # Print - Space
    graph  = yt.restrict "graph"  yt.string ( lib.test "[[:graph:]]+" );
    lower  = yt.restrict "lower"  yt.string ( lib.test "[[:lower:]]+" );
    # ! Cntrl
    print  = yt.restrict "print"  yt.string ( lib.test "[[:print:]]+" );
    # Graphical - AlNum
    punct  = yt.restrict "punct"  yt.string ( lib.test "[[:punct:]]+" );
    space  = yt.restrict "space"  yt.string ( lib.test "[[:space:]]+" );
    upper  = yt.restrict "upper"  yt.string ( lib.test "[[:upper:]]+" );
    # Base 16 Chars
    xdigit = yt.restrict "xdigit" yt.string ( lib.test "[[:xdigit:]]+" );
    base16 = yt.restrict "base16" yt.string lib.libstring.isBase16Str;
    base32 = yt.restrict "base32" yt.string lib.libstring.isBase32Str;
    base64 = yt.restrict "base64" yt.string lib.libstring.isBase64Str;
  };

  # TODO: URIs https://www.ietf.org/rfc/rfc2396.txt
  # NOTE: this is being done in `github:aakropotkin/rime'.


# ---------------------------------------------------------------------------- #

  # (Pred) Does `str' match `patt'?
  test = patt: str: ( builtins.match patt str ) != null;

  # Return the N'th capture group, or crash and burn.
  yankN' = n: patt: str: builtins.elemAt ( builtins.match patt str ) n;
  # Return the first capture group, or crash and burn.
  yank' = patt: str: builtins.head ( builtins.match patt str );
  # Return capture groups with indexes in `ns', or crash and burn.
  yankNs' = ns: patt: str:
    map ( builtins.elemAt ( builtins.match patt str ) ) ns;

  # Yankers which fallback to `null' on failure.
  yankN = n: patt: str: let
    m = builtins.match patt str;
  in if m == null then null else builtins.elemAt m n;
  yank = patt: str: let
    m = builtins.match patt str;
  in if m == null then null else builtins.head m;
  yankNs = ns: patt: str: let
    m = builtins.match patt str;
  in if m == null then null else map ( builtins.elemAt m ) ns;


# ---------------------------------------------------------------------------- #

  trim  = yank "[\t ]*([^\t ].*[^\t ])[\t ]*";
  lines = str: builtins.filter builtins.isString ( builtins.split "\n" str );


# ---------------------------------------------------------------------------- #

  # Force a value to a string.
  coerceString = x: let
    emitWarnThen = lib.warn "Unable to stringify type ${builtins.typeOf x}";
    coerceAs = as:
      builtins.toJSON ( builtins.mapAttrs ( _: v: coerceString v ) as );
  in if lib.strings.isCoercibleToString x then toString x else
     if lib.isFunction x   then "<LAMBDA>" else
     if builtins.isAttrs x then coerceAs x else
        emitWarnThen  "<???>";


# ---------------------------------------------------------------------------- #

  # Get character at index `n'.
  charN' = n: builtins.substring n 1;

  # Get character at index `n', wrapping if out of bounds.
  # charN 1 "hey"       ==> "h"
  # charN ( -1 ) "hey"  ==> "y"
  charN = n: str: let
    len = builtins.stringLength str;
    n' = lib.mod ( n + len ) len;
  in charN' n' str;


# ---------------------------------------------------------------------------- #

  pattHasCaret  = lib.test "^.*";
  pattHasDollar = lib.test ".*$";

  # Create a `grep' style matcher from `patt'.
  # FIXME: pattForLine = patt: "^.*${lib.yank "\\^?(.*)\\$?" patt}.*$";
  pattForLine = patt: let
    pre  = if pattHasCaret  patt then "" else "^.*";
    post = if pattHasDollar patt then "" else ".*$";
  in pre + patt + post;

  matchingLines = re: lines: builtins.filter ( test re ) lines;
  linesInfix    = re: lines: builtins.filter ( l: lib.hasInfix re l ) lines;
  readLines     = f: lib.splitString "\n" ( lib.fileContents f );

  linesGrep     = re: lines: matchingLines ( pattForLine re ) lines;
  readLinesGrep = re: f: linesGrep re ( readLines f );
  readGrep      = re: f: builtins.concatStringsSep "\n" ( readLinesGrep re f );


# ---------------------------------------------------------------------------- #

  applyToLines = f: x: let
    _lines = str: builtins.filter builtins.isString ( builtins.split "\n" str );
    asList = if ( builtins.isList x ) then x
      else if ( builtins.isString x ) then _lines x
      else if ( builtins.isPath x )   then lib.readLines x
      else throw ( "Cannot convert type ${builtins.typeOf x} to a list" +
                    " of strings" );
  in lib.concatMapStringsSep "\n" f asList;


# ---------------------------------------------------------------------------- #

  removeSlashSlashComment' = line: let
    ms = builtins.match "([^\"]*(\"[^\"]*\")*[^\"]*[^\\\"])?//.*" line;
    h  = builtins.head ms;
  in if ( ms == null ) then line else
     if h  == null then "" else h;

  removePoundComment' = line: let
    ms = builtins.match "([^\"]*(\"[^\"]*\")*[^\"]*[^\\\"])?#.*" line;
    h  = builtins.head ms;
  in if ms == null then line else
     if h  == null then "" else h;

  removeSlashSlashComments = applyToLines removeSlashSlashComment';
  removePoundComments      = applyToLines removePoundComment';

  removePoundDropEmpty = str: let
    proc = acc: l: let
      s = lib.libstr.removePoundComments l;
    in if ( builtins.isList l ) || ( s == "" ) then acc else
       if acc == "" then s else acc + "\n" + s;
  in builtins.foldl' proc "" ( builtins.split "\n" str );


# ---------------------------------------------------------------------------- #

  # Count the number of matches in a string.
  countMatches = splitter: string:
    let inherit (builtins) length split filter isList; in
    length ( filter isList ( split splitter string ) );


# ---------------------------------------------------------------------------- #

  # Return the longest common prefix for strings `a' and `b'.
  commonPrefix = a: b: let
    l = lib.strings.commonPrefixLength a b;
  in builtins.substring 0 l a;

  # Return the longest common suffix for strings `a' and `b'.
  commonSuffix = a: b: let
    l = lib.strings.commonSuffixLength a b;
  in builtins.substring ( l - 1 ) ( builtins.stringLength a ) a;


# ---------------------------------------------------------------------------- #

  # Convert "foo bar.baz", "foo_bar baz", or "foo-bar_baz" to "fooBarBaz".
  # Convert "foo" to "Foo".
  titleCase = str: let
    words = builtins.split "[. _-]" str;
    proc  = acc: w: let
      m = builtins.match "(.)(.*)" w;
      h = if ( builtins.head m ) == null then "" else
          lib.toUpper ( builtins.head m );
      t = if ( builtins.elemAt m 1 ) == null then "" else
          builtins.elemAt m 1;
    in if acc == null then w else
       if builtins.isList w then acc else
       acc + h + t;
    i = if ( builtins.length words ) < 2 then "" else null;
  in builtins.foldl' proc i words;


# ---------------------------------------------------------------------------- #

in {

  inherit (lib)
    splitString
    hasPrefix
    hasSuffix
    hasInfix
    fileContents
  ;

  inherit (lib.strings)
    commonPrefixLength
    commonSuffixLength
  ;

  inherit
    base16Chars'
    base16Chars
    base32Chars'
    base32Chars
    base64Chars'
    base64Chars
    isBase16Str
    isBase32Str
    isBase64Str
    yankN'
    yank'
    yankNs'
    yankN
    yank
    yankNs
    coerceString
    charN
    countMatches
    test
    commonPrefix
    commonSuffix
    matchingLines
    linesInfix
    readLines
    linesGrep
    readLinesGrep
    readGrep
    trim
    lines
  ;

  inherit
    applyToLines
    removeSlashSlashComment'
    removeSlashSlashComments
    removePoundComment'
    removePoundComments
    removePoundDropEmpty
    titleCase
  ;

  inherit ytypes;

}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
