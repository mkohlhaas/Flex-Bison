%{
#include <glib.h>
GPtrArray *a;
gboolean cmp0 (gconstpointer a, gconstpointer b);
gint     cmp1 (gconstpointer a, gconstpointer b);
%}

%%

[a-zA-Z]+ {
             GString *word = g_string_new(yytext);
             g_string_ascii_down(word);
             // sort out short words
             if(word->len > 3 && !g_ptr_array_find_with_equal_func(a, word, (GEqualFunc) cmp0, NULL) ) {
               g_ptr_array_add(a, word);
             }
          }
.
\n

%%

void prn(gpointer gStr) {
  GString *word = (GString*)gStr;
  printf("%s\n", word->str);
}

gboolean cmp0 (gconstpointer a, gconstpointer b){
  GString *x = (GString*) a;
  GString *y = (GString*) b;
  return g_strcmp0(x->str, y->str) ? FALSE : TRUE;
}

gint cmp1 (gconstpointer a, gconstpointer b){
  GString *x = *(GString**) a;
  GString *y = *(GString**) b;
  return g_strcmp0(x->str, y->str);
}

int main(void) {
  a = g_ptr_array_new();
  yylex();
  g_ptr_array_sort(a, (GCompareFunc)cmp1);
  g_ptr_array_foreach(a, (GFunc)prn, NULL);
}
