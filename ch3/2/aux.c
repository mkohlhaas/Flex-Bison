/* helper functions */

#include "aux.h"
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yyparse();

/* symbol table */
symbol symtab[NHASH];

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
    if (sp->name && !strcmp(sp->name, sym)) {
      return sp;
    }

    if (!sp->name) { /* new entry */
      sp->name = strdup(sym);
      sp->value = 0;
      sp->func = NULL;
      sp->syms = NULL;
      return sp;
    }

    if (++sp >= symtab + NHASH)
      sp = symtab; /* try the next entry */
  }
  yyerror("symbol table overflow\n");
  abort(); /* tried them all, table is full */
}

ast *newast(int nodetype, ast *l, ast *r) {
  ast *a = malloc(sizeof(ast));

  if (!a) {
    yyerror("out of memory");
    exit(EXIT_FAILURE);
  }

  a->nodetype = nodetype;
  a->l = l;
  a->r = r;
  return a;
}

ast *newnum(double d) {
  numval *a = malloc(sizeof(numval));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = 'K';
  a->number = d;
  return (ast *)a;
}

ast *newcmp(int cmptype, ast *l, ast *r) {
  ast *a = malloc(sizeof(ast));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = '0' + cmptype;
  a->l = l;
  a->r = r;
  return a;
}

ast *newfunc(int functype, ast *l) {
  fncall *a = malloc(sizeof(fncall));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = 'F';
  a->l = l;
  a->functype = functype;
  return (ast *)a;
}

ast *newcall(symbol *s, ast *l) {
  ufncall *a = malloc(sizeof(ufncall));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = 'C';
  a->l = l;
  a->s = s;
  return (ast *)a;
}

ast *newref(symbol *s) {
  symref *a = malloc(sizeof(symref));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = 'N';
  a->s = s;
  return (ast *)a;
}

ast *newasgn(symbol *s, ast *v) {
  symasgn *a = malloc(sizeof(symasgn));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = '=';
  a->s = s;
  a->v = v;
  return (ast *)a;
}

ast *newflow(int nodetype, ast *cond, ast *tl, ast *el) {
  flow *a = malloc(sizeof(flow));

  if (!a) {
    yyerror("out of memory");
    exit(0);
  }
  a->nodetype = nodetype;
  a->cond = cond;
  a->tl = tl;
  a->el = el;
  return (ast *)a;
}

symlist *newsymlist(symbol *sym, symlist *next) {
  symlist *sl = malloc(sizeof(symlist));

  if (!sl) {
    yyerror("out of memory");
    exit(0);
  }
  sl->sym = sym;
  sl->next = next;
  return sl;
}

void symlistfree(symlist *sl) {
  symlist *nsl;

  while (sl) {
    nsl = sl->next;
    free(sl);
    sl = nsl;
  }
}

/* define a function */
void dodef(symbol *name, symlist *syms, ast *func) {
  if (name->syms)
    symlistfree(name->syms);
  if (name->func)
    treefree(name->func);
  name->syms = syms;
  name->func = func;
}

static double callbuiltin(fncall *);
static double calluser(ufncall *);

double eval(ast *a) {
  double v;

  if (!a) {
    yyerror("internal error, null eval");
    return 0.0;
  }

  switch (a->nodetype) {
    /* constant */
  case 'K':
    v = ((numval *)a)->number;
    break;

    /* name reference */
  case 'N':
    v = ((symref *)a)->s->value;
    break;

    /* assignment */
  case '=':
    v = ((symasgn *)a)->s->value = eval(((symasgn *)a)->v);
    break;

    /* expressions */
  case '+':
    v = eval(a->l) + eval(a->r);
    break;
  case '-':
    v = eval(a->l) - eval(a->r);
    break;
  case '*':
    v = eval(a->l) * eval(a->r);
    break;
  case '/':
    v = eval(a->l) / eval(a->r);
    break;
  case '|':
    v = fabs(eval(a->l));
    break;
  case 'M':
    v = -eval(a->l);
    break;

    /* comparisons */
  case '1':
    v = (eval(a->l) > eval(a->r)) ? 1 : 0;
    break;
  case '2':
    v = (eval(a->l) < eval(a->r)) ? 1 : 0;
    break;
  case '3':
    v = (eval(a->l) != eval(a->r)) ? 1 : 0;
    break;
  case '4':
    v = (eval(a->l) == eval(a->r)) ? 1 : 0;
    break;
  case '5':
    v = (eval(a->l) >= eval(a->r)) ? 1 : 0;
    break;
  case '6':
    v = (eval(a->l) <= eval(a->r)) ? 1 : 0;
    break;

  /* control flow */
  /* null if/else/do expressions allowed in the grammar, so check for them */
  case 'I':
    if (eval(((flow *)a)->cond) != 0) {
      if (((flow *)a)->tl) {
        v = eval(((flow *)a)->tl);
      } else
        v = 0.0; /* a default value */
    } else {
      if (((flow *)a)->el) {
        v = eval(((flow *)a)->el);
      } else
        v = 0.0; /* a default value */
    }
    break;

  case 'W':
    v = 0.0; /* a default value */

    if (((flow *)a)->tl) {
      while (eval(((flow *)a)->cond) != 0)
        v = eval(((flow *)a)->tl);
    }
    break; /* last value is value */

  case 'L':
    eval(a->l);
    v = eval(a->r);
    break;

  case 'F':
    v = callbuiltin((fncall *)a);
    break;

  case 'C':
    v = calluser((ufncall *)a);
    break;

  default:
    printf("internal error: bad node %c\n", a->nodetype);
  }
  return v;
}

static double callbuiltin(fncall *f) {
  enum bifs functype = f->functype;
  double v = eval(f->l);

  switch (functype) {
  case B_sqrt:
    return sqrt(v);
  case B_exp:
    return exp(v);
  case B_log:
    return log(v);
  case B_print:
    printf("= %4.4g\n", v);
    return v;
  default:
    yyerror("Unknown built-in function %d", functype);
    return 0.0;
  }
}

static double calluser(ufncall *f) {
  symbol *fn = f->s;       /* function name */
  symlist *sl;             /* dummy arguments */
  ast *args = f->l;        /* actual arguments */
  double *oldval, *newval; /* saved arg values */
  double v;
  int nargs;
  int i;

  if (!fn->func) {
    yyerror("call to undefined function", fn->name);
    return 0;
  }

  /* count the arguments */
  sl = fn->syms;
  for (nargs = 0; sl; sl = sl->next)
    nargs++;

  /* prepare to save them */
  oldval = (double *)malloc(nargs * sizeof(double));
  newval = (double *)malloc(nargs * sizeof(double));
  if (!oldval || !newval) {
    yyerror("out of memory in %s", fn->name);
    return 0.0;
  }

  /* evaluate the arguments */
  for (i = 0; i < nargs; i++) {
    if (!args) {
      yyerror("too few args in call to %s", fn->name);
      free(oldval);
      free(newval);
      return 0;
    }

    if (args->nodetype == 'L') { /* if this is a list node */
      newval[i] = eval(args->l);
      args = args->r;
    } else { /* if it's the end of the list */
      newval[i] = eval(args);
      args = NULL;
    }
  }

  /* save old values of dummies, assign new ones */
  sl = fn->syms;
  for (i = 0; i < nargs; i++) {
    symbol *s = sl->sym;

    oldval[i] = s->value;
    s->value = newval[i];
    sl = sl->next;
  }

  free(newval);

  /* evaluate the function */
  v = eval(fn->func);

  /* put the dummies back */
  sl = fn->syms;
  for (i = 0; i < nargs; i++) {
    symbol *s = sl->sym;

    s->value = oldval[i];
    sl = sl->next;
  }

  free(oldval);
  return v;
}

void treefree(ast *a) {
  switch (a->nodetype) {

    /* two subtrees */
  case '+':
  case '-':
  case '*':
  case '/':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case 'L':
    treefree(a->r);

    /* one subtree */
  case '|':
  case 'M':
  case 'C':
  case 'F':
    treefree(a->l);

    /* no subtree */
  case 'K':
  case 'N':
    break;

  case '=':
    free(((symasgn *)a)->v);
    break;

  case 'I':
  case 'W':
    free(((flow *)a)->cond);
    if (((flow *)a)->tl)
      free(((flow *)a)->tl);
    if (((flow *)a)->el)
      free(((flow *)a)->el);
    break;

  default:
    printf("internal error: free bad node %c\n", a->nodetype);
  }

  free(a); /* always free the node itself */
}

void yyerror(char *s, ...) {
  va_list ap;
  va_start(ap, s);

  fprintf(stderr, "%d: error: ", yylineno);
  vfprintf(stderr, s, ap);
  fprintf(stderr, "\n");
}

int main() {
  printf("> ");
  return yyparse();
}

/* debugging: dump out an AST */
int debug = 0;
void dumpast(ast *a, int level) {

  printf("%*s", 2 * level, ""); /* indent to this level */
  level++;

  if (!a) {
    printf("NULL\n");
    return;
  }

  switch (a->nodetype) {
    /* constant */
  case 'K':
    printf("number %4.4g\n", ((numval *)a)->number);
    break;

    /* name reference */
  case 'N':
    printf("ref %s\n", ((symref *)a)->s->name);
    break;

    /* assignment */
  case '=':
    printf("= %s\n", ((symref *)a)->s->name);
    dumpast(((symasgn *)a)->v, level);
    return;

    /* expressions */
  case '+':
  case '-':
  case '*':
  case '/':
  case 'L':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
    printf("binop %c\n", a->nodetype);
    dumpast(a->l, level);
    dumpast(a->r, level);
    return;

  case '|':
  case 'M':
    printf("unop %c\n", a->nodetype);
    dumpast(a->l, level);
    return;

  case 'I':
  case 'W':
    printf("flow %c\n", a->nodetype);
    dumpast(((flow *)a)->cond, level);
    if (((flow *)a)->tl)
      dumpast(((flow *)a)->tl, level);
    if (((flow *)a)->el)
      dumpast(((flow *)a)->el, level);
    return;

  case 'F':
    printf("builtin %d\n", ((fncall *)a)->functype);
    dumpast(a->l, level);
    return;

  case 'C':
    printf("call %s\n", ((ufncall *)a)->s->name);
    dumpast(a->l, level);
    return;

  default:
    printf("bad %c\n", a->nodetype);
    return;
  }
}
