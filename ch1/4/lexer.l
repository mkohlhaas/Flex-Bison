/* Recognize tokens for the calculator and print them out. */

%{
   enum yytokentype {
     NUMBER = 258,
     ADD    = 259,
     SUB    = 260,
     MUL    = 261,
     DIV    = 262,
     ABS    = 263,
     EOL    = 264 /* end of line */
   };

   int yylval;

%}

%%

"+"	       { return ADD; }
"-"	       { return SUB; }
"*"	       { return MUL; }
"/"	       { return DIV; }
"|"        { return ABS; }
[0-9]+	   { yylval = atoi(yytext); return NUMBER; }
\n         { return EOL; }
[ \t]      { /* ignore white space */ }
.	         { printf("Mystery character %c\n", *yytext); }

%%

int main(void) {
  int tok;

  while ((tok = yylex())) {
    if (tok == NUMBER) {
      printf("%d = %d\n", tok, yylval);
    } else {
      printf("%d\n", tok);
    }
  }
}
