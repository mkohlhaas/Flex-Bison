/* text concordance */

%option noyywrap nodefault yylineno case-insensitive

/* the symbol table */
%{
  typedef struct ref {
    struct ref *next;
    char *filename;
    int flags;
    int lineno;
  } ref;

  typedef struct {		/* a word */
    struct ref *reflist;
    char *name;
  } symbol;

  /* simple symtab of fixed size */
  #define NHASH 9997
  symbol symtab[NHASH];

  symbol *lookup(char*);
  void addref(int, char*, char*, int);

  char *curfilename;		/* name of current input file */
%}

%%

 /* skip common words */
a    |
an   |
and  |
are  |
as   |
at   |
be   |
but  |
for  |
in   |
is   |
it   |
of   |
on   |
or   |
that |
the  |
this |
to                /* ignore */

[a-z]+(\'(s|t))?  { addref(yylineno, curfilename, yytext, 0); }
.|\n              /* ignore everything else */

%%

int nnew;
int nold;
int nprobe;

/* hash a symbol */
static unsigned symhash(char *sym) {
  unsigned int hash = 0;
  unsigned c;

  while ((c = *sym++)) {
    hash = hash * 9 ^ c;
  }

  return hash;
}

symbol *lookup(char *sym) {
  symbol *sp = &symtab[symhash(sym) % NHASH];
  int scount = NHASH; /* how many have we looked at */

  while (--scount >= 0) {
    nprobe++;
    if (sp->name && !strcmp(sp->name, sym)) {
      nold++;
      return sp;
    }

    if (!sp->name) { /* new entry */
      nnew++;
      sp->name = strdup(sym);
      sp->reflist = 0;
      return sp;
    }

    if (++sp >= symtab + NHASH)
      sp = symtab; /* try the next entry */
  }
  fputs("symbol table overflow\n", stderr);
  abort(); /* tried them all, table is full */
}

void addref(int lineno, char *filename, char *word, int flags) {
  ref *r;
  symbol *sp = lookup(word);

  /* don't do dups */
  if (sp->reflist && sp->reflist->lineno == lineno && sp->reflist->filename == filename) {
    return;
  }

  r = malloc(sizeof(ref));
  if (!r) {
    fprintf(stderr, "out of space\n");
    abort();
  }
  r->next = sp->reflist;
  r->filename = filename;
  r->lineno = lineno;
  r->flags = flags;
  sp->reflist = r;
}

/* print the references
 * sort the table alphabetically
 * then flip each entry's reflist to get it into forward order
 * and print it out
 */

/* aux function for sorting */
static int symcompare(const void *xa, const void *xb) {
  const symbol *a = xa;
  const symbol *b = xb;

  if (!a->name) {
    if (!b->name)
      return 0; /* both empty */
    return 1;   /* put empties at the end */
  }
  if (!b->name)
    return -1;
  return strcmp(a->name, b->name);
}

void printrefs() {
  symbol *sp;

  qsort(symtab, NHASH, sizeof(symbol), symcompare); /* sort the symbol table */

  for (sp = symtab; sp->name && sp < symtab + NHASH; sp++) {
    char *prevfn = NULL; /* last printed filename, to skip dups */

    /* reverse the list of references */
    ref *rp = sp->reflist;
    ref *rpp = NULL; /* previous ref */
    ref *rpn;     /* next ref */

    do {
      rpn = rp->next;
      rp->next = rpp;
      rpp = rp;
      rp = rpn;
    } while (rp);

    /* now print the word and its references */
    printf("%10s", sp->name);
    for (rp = rpp; rp; rp = rp->next) {
      if (rp->filename == prevfn) {
        printf(" %d", rp->lineno);
      } else {
        printf(" %s:%d", rp->filename, rp->lineno);
        prevfn = rp->filename;
      }
    }
    printf("\n");
  }
}

int main(int argc, char **argv) {
  if (argc < 2) { /* just read stdin */
    curfilename = "(stdin)";
    yylineno = 1;
    yylex();
  } else
    for (int i = 1; i < argc; i++) {
      FILE *file = fopen(argv[i], "r");

      if (!file) {
        perror(argv[1]);
        exit(EXIT_FAILURE);
      }
      curfilename = argv[i]; /* for addref */

      yyrestart(file);
      yylineno = 1;
      yylex();
      fclose(file);
    }

  printf("old = %d, new = %d, total = %d, probes = %d, avg = %1.2f\n", nold, nnew, nold + nnew, nprobe, (float)nprobe / (nold + nnew));

  printrefs();
}
