/* text concordance */

%option noyywrap nodefault yylineno case-insensitive

/* the symbol table */
%{
  #include <ctype.h>

  // used by a word to record where it has been found (filename, line number)
  // 'reference' implemented as linked list.
  typedef struct ref {
    struct ref *next;
    char *filename;
    int lineno;
  } ref;

  // 'symbol' → a word and its references
  typedef struct {
    char *word;
    struct ref *reflist;
  } symbol;

  /* simple symtab of fixed size */
  // NHASH is a prime number
  #define NHASH 9997
  symbol symtab[NHASH] = {0};

  symbol *lookup(char*);
  void addref(int, char*, char*);

  char *curfilename;		/* name of current input file */
%}

%%

 /* skip common words */
a      |
all    |
am     |
an     |
and    |
are    |
as     |
at     |
be     |
both   |
but    |
by     |
can    |
cannot |
come   |
d      |
did    |
do     |
for    |
from   |
he     |
her    |
him    |
his    |
i      |
if     |
in     |
is     |
it     |
let    |
make   |
may    |
me     |
mine   |
might  |
more   |
most   |
much   |
must   |
my     |
no     |
not    |
o      |
of     |
on     |
or     |
our    |
say    |
see    |
shall  |
should |
so     |
some   |
t      |
that   |
the    |
these  |
this   |
to     |
true   |
very   |
was    |
we     |
what   |
will   |
with   |
would  |
y      |
yet    |
you    |
your   |
yours

[a-z]+(\'(s|t))?  { addref(yylineno, curfilename, yytext); }
.|\n              /* ignore everything else */

%%

int nnew;
int nold;
int nprobe;

/* hash a symbol */
static unsigned symhash(char *word) {
  unsigned int hash = 0;
  unsigned c;

  while ((c = *word++)) {
    hash = hash * 9 ^ c;
  }

  return hash;
}

// lookup word; if not found create a new entry into symtab; make a copy of word!!!
symbol *lookup(char *word) {
  symbol *sp = &symtab[symhash(word) % NHASH];
  int scount = NHASH; /* how many have we looked at */

  while (--scount >= 0) {
    nprobe++;
    if (sp->word && !strcmp(sp->word, word)) {
      nold++;
      return sp;
    }
    /* new entry */
    if (!sp->word) {
      nnew++;
      sp->word = strdup(word); // making a copy of yytext!!!
      sp->reflist = 0;
      return sp;
    }

    // hashing with linear probing
    if (++sp >= symtab + NHASH)
      sp = symtab; /* try the next entry */
  }
  fputs("symbol table overflow\n", stderr);
  abort(); /* tried them all, table is full */
}

void addref(int lineno, char *filename, char *word) {
  *word = tolower(*word);
  symbol *pSymbol = lookup(word);

  /* ignore duplicates */
  if (pSymbol->reflist && pSymbol->reflist->lineno == lineno && pSymbol->reflist->filename == filename) {
    return;
  }

  ref *ref = malloc(sizeof(ref));
  if (!ref) {
    perror("out of memory\n");
    exit(EXIT_FAILURE);
  }
  ref->next = pSymbol->reflist;
  ref->filename = filename;
  ref->lineno = lineno;
  pSymbol->reflist = ref;
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

  if (!a->word) {
    {
      if (!b->word) {
        return 0; /* both empty */
      }
      return 1; /* put empties at the end */
    }
  }
  if (!b->word) {
    return -1;
  }
  return strcmp(a->word, b->word);
}

void printrefs() {
  symbol *pSymbol;

  qsort(symtab, NHASH, sizeof(symbol), symcompare); /* sort the symbol table */

  for (pSymbol = symtab; pSymbol->word && pSymbol < symtab + NHASH; pSymbol++) {
    char *prevfn = NULL; /* last printed filename, to skip dups */

    /* reverse the list of references */
    ref *rp = pSymbol->reflist;
    ref *rpp = NULL; /* previous ref */
    ref *rpn;     /* next ref */

    do {
      rpn = rp->next;
      rp->next = rpp;
      rpp = rp;
      rp = rpn;
    } while (rp);

    /* now print the word and its references */
    printf("%15s", pSymbol->word);
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
