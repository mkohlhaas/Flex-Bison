/* skeleton for include files */

%option noyywrap warn nodefault
%x IFILE

/* indented text will also be copied verbatimly */

 typedef struct bufstack {
   struct bufstack *prev;
   YY_BUFFER_STATE bs;
   int lineno;
   char *filename;
   FILE *file;
 } bufstack;

 bufstack *curBS = NULL;  /* current buffer stack */

 char *curFilename;       /* name of current input file */

 int newfile(char *filename);
 int popfile(void);

%%

^"#"[ \t]*include[ \t]*[\"<] { BEGIN IFILE; }
^.                           { fprintf(yyout, "%5d %s", yylineno,   yytext); } /* print line number and first character of line */
^\n                          { fprintf(yyout, "%5d %s", yylineno++, yytext); } /* print empty lines (yytext → newline) */
.                            { ECHO; }                                         /* print current character ("." → anything but newline) */
\n                           { ECHO; yylineno++; }                             /* print newline */
<<EOF>>                      {
                               if(!popfile()) {
                                 yyterminate();
                               }
                             }

<IFILE>[^ \t\n\">]+          {
                               { int c;
                        			   while((c = input()) && c != '\n') ;
                        			 }
                        			 if(!newfile(yytext)) {
                                 yyterminate(); /* no such file */
                               }
                        			 BEGIN INITIAL;
                             }

<IFILE>.|\n                  { fprintf(stderr, "%d bad include line\n", yylineno); yyterminate(); }

%%

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "need filename\n");
    exit(EXIT_FAILURE);
  }

  if (newfile(argv[1])) {
    yylex();
  }
}

// opens file, creates a new buffer and switches to it
int newfile(char *filename) {
  FILE *file = fopen(filename, "r");
  bufstack *bs = malloc(sizeof(bufstack));

  /* die if no file or no room */
  if (!file) {
    perror(filename);
    return 0;
  }

  if (!bs) {
    perror("malloc");
    exit(EXIT_FAILURE);
  }

  /* remember state */
  if (curBS) {
    curBS->lineno = yylineno;
  }
  bs->prev = curBS;

  /* set up current entry */
  bs->bs = yy_create_buffer(file, YY_BUF_SIZE);
  bs->file = file;
  bs->filename = filename;
  yy_switch_to_buffer(bs->bs);
  curBS = bs;
  yylineno = 1;
  curFilename = filename;
  return 1;
}

// goes back to previous buffer stack (if available)
int popfile(void) {
  bufstack *bs = curBS;
  bufstack *prevbs;

  if (!bs) {
    return 0;
  }

  /* get rid of current entry */
  fclose(bs->file);
  yy_delete_buffer(bs->bs);

  /* switch back to previous */
  prevbs = bs->prev;
  free(bs);

  if (!prevbs) {
    return 0;
  }

  yy_switch_to_buffer(prevbs->bs);
  curBS = prevbs;
  yylineno = curBS->lineno;
  curFilename = curBS->filename;
  return 1;
}
