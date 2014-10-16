#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sio.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "lexer.h"
#include "parse.h"
#include "obj.h"
#include "parsehelper.h"
#include "compile.h"
#include "runtime0.h"
#include "runtime.h"
#include "repl.h"

void do_str(const char *src) {
    mp_lexer_t *lex = mp_lexer_new_from_str_len(MP_QSTR__lt_stdin_gt_, src, strlen(src), 0);
    if (lex == NULL) {
        return;
    }

    mp_parse_error_kind_t parse_error_kind;
    mp_parse_node_t pn = mp_parse(lex, MP_PARSE_SINGLE_INPUT, &parse_error_kind);
	
    if (pn == MP_PARSE_NODE_NULL) {
        // parse error
        mp_parse_show_exception(lex, parse_error_kind);
        mp_lexer_free(lex);
printf("\n%s %d\n", __FUNCTION__, __LINE__);
        return;
    }

    // parse okay
    qstr source_name = mp_lexer_source_name(lex);
    mp_lexer_free(lex);
    mp_obj_t module_fun = mp_compile(pn, source_name, MP_EMIT_OPT_NONE, true);

    if (mp_obj_is_exception_instance(module_fun)) {
        // compile error
        mp_obj_print_exception(module_fun);
        return;
    }

    nlr_buf_t nlr;
    if (nlr_push(&nlr) == 0) {
        mp_call_function_0(module_fun);
        nlr_pop();
    } else {
        // uncaught exception
        mp_obj_print_exception((mp_obj_t)nlr.ret_val);
    }
}

int main(int argc, char **argv) {
    char line[1024];

    mp_init();

#if 0
    do_str("print('hello world!')");
    do_str("print(123)");
    do_str("a = 1000");
    do_str("b = 1");
    do_str("print(a - b)");
    do_str("for x in range(3):");
    do_str("    print(x)");
    do_str("");
#endif

#if 0
    do {
	printf(">>> ");
	gets(line, 256);
	if (line[0] == '.')
		break;
    	do_str(line);
    } while (1);
#endif

    for (;;) {
	printf(">>> ");
	gets(line, 256);
	if (line[0] == '.')
		break;
        while (mp_repl_continue_with_input(line)) {
	    int pos = strlen(line);
	    printf("... ");
	    gets(&line[pos], 256);
	    if (line[pos] == 0)
		break;
        }
    	do_str(line);
    }

    mp_deinit();
    return 0;
}

void gc_collect(void) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
}

mp_lexer_t *mp_lexer_new_from_file(const char *filename) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
    return NULL;
}

mp_import_stat_t mp_import_stat(const char *path) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
    return MP_IMPORT_STAT_NO_EXIST;
}

mp_obj_t mp_builtin_open(uint n_args, const mp_obj_t *args) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
    return mp_const_none;
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_builtin_open_obj, 1, 2, mp_builtin_open);

void nlr_jump_fail(void *val) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
}

void *realloc(void *ptr, size_t size)
{
	void *n;

	n = malloc(size);
	if (n == NULL)
		return NULL;
	memcpy(n, ptr, size);
	free(ptr);
	printf("\r\nrealloc %p %d\r\n", ptr, size);
	return n;
}

char *strcat(char *dest, const char *src) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
	return dest;
}

#include <stdarg.h>

extern int _xvprintf(char const *, void(*)(int, void *), void *, va_list);

static __attribute__((optimize("-Os"))) void
sio_pchar(int c, void *arg __unused)
{

        /* Translate CR -> CR + LF */
        if (c == '\n')
                sio_putchar('\r', 1);
        sio_putchar(c, 1);
}

int vprintf(const char *format, va_list ap)
{
        int retval;
        
        retval = _xvprintf(format, sio_pchar, NULL, ap);
        return (retval);
}

int vsnprintf(char *str,  size_t  size,  const  char  *format, va_list ap)
{
	return snprintf(str, size, format, ap);
}

#undef putchar
int putchar(int c)
{
	sio_pchar(c, 0);
	return 0;
}

int puts(const char *s)
{
	printf("%s", s);
	return 0;
}
