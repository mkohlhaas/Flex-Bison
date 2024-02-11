/* C cross-ref */

%option noyywrap nodefault yylineno

%x COMMENT
%x IFILE

/* some complex named patterns */
/* Universal Character Name */
UCN	(\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})

/* float exponent */
EXP	([Ee][-+]?[0-9]+)

/* integer length */
ILEN    ([Uu](L|l|LL|ll)?|(L|l|LL|ll)[Uu]?)

/* the symbol table */
%{
typedef struct { /* a variable name */
  struct ref *reflist;
  char *name;
} symbol;

typedef struct ref {
  struct ref *next;
  char *filename;
  int flags; /* 01 - definition */
  int lineno;
} ref;

/* simple symtab of fixed size */
#define NHASH 9997
symbol symtab[NHASH];

symbol *lookup(char *);
void addref(int, char *, char *, int);

char *curfilename; /* name of current input file */

int defining; /* names are probably definitions */

/* include file stack */
typedef struct bufstack {
  struct bufstack *prev; /* previous entry */
  YY_BUFFER_STATE bs;    /* saved buffer */
  int lineno;            /* saved line number in this file */
  char *filename;        /* name of this file */
  FILE *f;               /* current file */
} bufstack;

bufstack *curbs;

int newfile(char *fn);
int popfile(void);
%}

%%

 /* ignore comments */
"/*"                    { BEGIN(COMMENT) ; }
<COMMENT>"*/"           { BEGIN(INITIAL); }
<COMMENT>([^*]|\en)+|.

 /* C++ comment, a common extension */
"//".*\n

 /* declaration keywords */
_Bool      |
_Complex   |
_Imaginary |
auto       |
char       |
const      |
double     |
enum       |
extern     |
float      |
inline     |
int        |
long       |
register   |
restrict   |
short      |
signed     |
static     |
struct     |
typedef    |
union      |
unsigned   |
void       |
volatile   { defining = 1; }


 /* ignore keywords */
break
case
continue
default
do
else
for
goto
if
return
sizeof
switch
while

 /* constants */

 /* ignore integers */
0[0-7]*{ILEN}?
[1-9][0-9]*{ILEN}?
0[Xx][0-9a-fA-F]+{ILEN}?

 /* ignore decimal float */
([0-9]*\.[0-9]+|[0-9]+\.){EXP}?[flFL]?
[0-9]+{EXP}[flFL]?

 /* ignore hex float */
0[Xx]([0-9a-fA-F]*\.[0-9a-fA-F]+|[0-9a-fA-F]+\.?)[Pp][-+]?[0-9]+[flFL]?


 /* ignore char const */
\'([^'\\]|\\['"?\\abfnrtv]|\\[0-7]{1,3}|\\[Xx][0-9a-fA-F]+|{UCN})+\'

 /* ignore string literal */
L?\"([^\"\\]|\\['"?\\abfnrtv]|\\[0-7]{1,3}|\\[Xx][0-9a-fA-F]+|{UCN})+\"

 /* punctuators */
"{"|"<%"|";"         { defining = 0; }

 /* ignore */
"["|"]"|"("|")"|"{"|"}"|"."|"->"
"++"|"--"|"&"|"*"|"+"|"-"|"~"|"!"
"/"|"%"|"<<"|">>"|"<"|">"|"<="|">="|"=="|"!="|"^"|"|"|"&&"|"||"
"?"|":"|";"|"..."
"="|"*="|"/="|"%="|"+="|"-="|"<<="|">>="|"&="|"^=""|="
","|"#"|"##"
"<:"|":>"|"%>"|"%:"|"%:%:"

 /* identifier */
([_a-zA-Z]|{UCN})([_a-zA-Z0-9]|{UCN})* { addref(yylineno, curfilename, yytext, defining); }

 /* white space */
[ \t\n]+
 /* continued line */
\\$

 /* ignore preprocessor stuff */
"#"" "*if.*\n
"#"" "*else.*\n
"#"" "*endif.*\n
"#"" "*define.*\n
"#"" "*line.*\n

 /* recognize an include */
^"#"[ \t]*include[ \t]*[\"<] { BEGIN IFILE; }

<IFILE>[^>\"]+  {
                  int c;
			            while((c = input()) && c != '\n');
		              newfile(strdup(yytext));
		              BEGIN INITIAL;
                }

<IFILE>.|\n     {
                  fprintf(stderr, "%s:%d bad include line\n", curfilename, yylineno);
                  BEGIN INITIAL;
                }

<<EOF>>         {
                  if(!popfile()) {
                    yyterminate();
                  }
                }

 /* invalid character */
.               { printf("%s:%d: Mystery character '%s'\n", curfilename, yylineno, yytext); }

%%

/* hash a symbol */
static unsigned symhash(char *sym) {
  unsigned int hash = 0;
  unsigned c;

  while (c = *sym++)
    hash = hash * 9 ^ c;

  return hash;
}

symbol *lookup(char *sym) {
  symbol *sp = &symtab[symhash(sym) % NHASH];
  int scount = NHASH; /* how many have we looked at */

  while (--scount >= 0) {
    if (sp->name && !strcmp(sp->name, sym)) {
      return sp;
    }

    if (!sp->name) { /* new entry */
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
  if (sp->reflist && sp->reflist->lineno == lineno && sp->reflist->filename == filename)
    return;

  r = malloc(sizeof(ref));
  if (!r) {
    fputs("out of space\n", stderr);
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
    ref *rpp = 0; /* previous ref */
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
      if (rp->flags & 01)
        printf("*");
    }
    printf("\n");
  }
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "need filename\n");
    exit(EXIT_FAILURE);
  }
  for (int i = 1; i < argc; i++) {
    if (newfile(argv[i]))
      yylex();
  }

  printrefs();
}

/* nested input files */
int newfile(char *fn) {
  FILE *f = fopen(fn, "r");
  struct bufstack *bs;

  /* check if no file */
  if (!f) {
    perror(fn);
    return 0;
  }

  bs = malloc(sizeof(struct bufstack));
  if (!bs) {
    perror("malloc");
    exit(1);
  }

  /* remember state */
  if (curbs)
    curbs->lineno = yylineno;

  bs->prev = curbs;
  bs->f = f;
  bs->filename = fn;

  /* set up current entry */
  bs->bs = yy_create_buffer(f, YY_BUF_SIZE);
  yy_switch_to_buffer(bs->bs);
  curbs = bs;
  yylineno = 1;
  curfilename = fn;
  return 1;
}

int popfile(void) {
  struct bufstack *bs = curbs;
  struct bufstack *prevbs;

  if (!bs)
    return 0;

  /* get rid of current entry
  fclose(bs->f);
  yy_delete_buffer(bs->bs);

  /* switch back to previous */
  prevbs = bs->prev;
  free(bs);

  if (!prevbs)
    return 0;

  yy_switch_to_buffer(prevbs->bs);
  curbs = prevbs;
  yylineno = curbs->lineno;
  curfilename = curbs->filename;
  return 1;
}
