/* English → American */

%%

"colour"  { printf("color"); }
"flavour" { printf("flavor"); }
"clever"  { printf("smart"); }
"smart"   { printf("elegant"); }
"liberal" { printf("conservative"); }
.         { printf("%s", yytext); }

%%

int main(void)
{
  yylex();
}
