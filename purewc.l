/* word count, pure version */

%option noyywrap nodefault reentrant
%{
struct pwc {
    int chars;
    int words;
    int lines;
};
%}
%option extra-type="struct pwc *"

%%
%{
  struct pwc *pp = yyextra;
%}

[a-zA-Z]+	{ pp->words++; pp->chars += strlen(yytext); }
\n		{ pp->chars++; pp->lines++; }
.		{ pp->chars++; }

%%

main(argc, argv)
int argc;
char **argv;
{
  struct pwc mypwc = { 0, 0, 0 }; /* my instance data */
  yyscan_t lexer;		  /* flex instance data */

  if(yylex_init_extra(&mypwc, &lexer)) {
    perror("init alloc failed");
    return 1;
  }

  if(argc > 1) {
    FILE *f;

    if(!(f = fopen(argv[1], "r"))) {
      perror(argv[1]);
      return (1);
    }
    yyset_in(f, lexer);
  } else
    yyset_in(stdin, lexer);

  yylex(lexer);
  printf("%8d%8d%8d\n", mypwc.lines, mypwc.words, mypwc.chars);

  if(argc > 1)
    fclose(yyget_in(lexer));

  yylex_destroy( lexer );

}

