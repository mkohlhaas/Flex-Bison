/* read several files */

%option noyywrap

%{
int chars = 0;
int words = 0;
int lines = 0;

int totchars = 0;
int totwords = 0;
int totlines = 0;
%}

%%

[^ \t\n\r\f\v]+ { words++; chars += strlen(yytext); }
\n		          { chars++; lines++; }
.		            { chars++; }

%%

int main(int argc, char **argv) {

  // just read stdin
  if (argc < 2) {
    yylex();
    printf("lines: %d, words: %d, chars: %d\n", lines, words, chars);
    exit(EXIT_SUCCESS);
  }

  // iterate files
  for (int i = 1; i < argc; i++) {
    // open file
    FILE *f = fopen(argv[i], "r");
    if (!f) {
      perror(argv[i]);
      exit(EXIT_FAILURE);
    }

    // lexing file
    yyrestart(f);
    yylex();

    // updating totals
    totlines += lines;
    totwords += words;
    totchars += chars;

    // print results
    printf("%s → lines: %d, words: %d, chars: %d\n",  argv[i], lines, words, chars);

    // resetting vars
    lines = 0;
    chars = 0;
    words = 0;

    // cleanup
    fclose(f);
  }

  if (argc > 1) {
    printf("total lines: %d, total words: %d, total chars: %d\n", totlines, totwords, totchars);
  }
}
