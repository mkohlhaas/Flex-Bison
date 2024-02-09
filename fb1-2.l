/* English -> American */

%%
"colour" { printf("color"); }
"flavour" { printf("flavor"); }
"clever" { printf("smart"); }
"smart" { printf("elegant"); }
"liberal" { printf("conservative"); }
. { printf("%s", yytext); }
%%
main()
{
  yylex();
}

yywrap() { return 1; }
