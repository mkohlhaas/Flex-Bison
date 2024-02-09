/* fb1-1 just like unix wc */

%{
int chars = 0;
int words = 0;
int lines = 0;
%}

%%

[a-zA-Z]+	{ words++; chars += strlen(yytext); }
\n		    { chars++; lines++; }
.		      { chars++; }

%%

main()
{
  yylex();
  printf("%8d %8d %8d\n", lines, words, chars);
}
