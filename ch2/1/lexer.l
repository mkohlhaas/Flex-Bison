/* even more like unix wc with explicit input */

%{
int chars = 0;
int words = 0;
int lines = 0;
%}

%%

[^ \t\n\r\f\v]+ { words++; chars += strlen(yytext); }
\n		          { chars++; lines++; }
.		            { chars++; }

%%

int main(int argc, char **argv) {
  if(argc > 1) {
    if(!(yyin = fopen(argv[1], "r"))) {
      perror(argv[1]);
      exit(EXIT_FAILURE);
    }
  }

  yylex();
  printf("lines: %d, words: %d, chars: %d\n", lines, words, chars);
}

int yywrap() { return 1; }
