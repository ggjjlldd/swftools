/* parser.lex

   Routines for compiling Flash2 AVM2 ABC Actionscript

   Extension module for the rfxswf library.
   Part of the swftools package.

   Copyright (c) 2008 Matthias Kramm <kramm@quiss.org>
 
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */
%{
#include <stdlib.h>
#include <stdio.h>
#include <memory.h>
#include "abc.h"
#include "pool.h"
#include "files.h"
#include "tokenizer.h"
#include "registry.h"
#include "code.h"
#include "opcodes.h"

%}

//%glr-parser
//%expect-rr 1
%error-verbose

%union tokenunion {
    enum yytokentype token;
    int flags;

    classinfo_t*classinfo;
    classinfo_list_t*classinfo_list;

    int number_int;
    unsigned int number_uint;
    double number_float;
    code_t*code;
    typedcode_t value;
    //typedcode_list_t*value_list;
    codeandnumber_t value_list;
    param_t* param;
    params_t params;
    string_t str;
    char*id;
    constant_t*constant;
    for_start_t for_start;
}


%token<id> T_IDENTIFIER
%token<str> T_STRING
%token<token> T_REGEXP
%token<token> T_EMPTY
%token<number_int> T_INT
%token<number_uint> T_UINT
%token<number_uint> T_BYTE
%token<number_uint> T_SHORT
%token<number_float> T_FLOAT

%token<id> T_FOR "for"
%token<id> T_WHILE "while"
%token<id> T_DO "do"
%token<id> T_SWITCH "switch"

%token<token> KW_IMPLEMENTS
%token<token> KW_NAMESPACE "namespace"
%token<token> KW_PACKAGE "package"
%token<token> KW_PROTECTED
%token<token> KW_PUBLIC
%token<token> KW_PRIVATE
%token<token> KW_USE "use"
%token<token> KW_INTERNAL
%token<token> KW_NEW "new"
%token<token> KW_NATIVE
%token<token> KW_FUNCTION "function"
%token<token> KW_UNDEFINED "undefined"
%token<token> KW_CONTINUE "continue"
%token<token> KW_CLASS "class"
%token<token> KW_CONST "const"
%token<token> KW_CATCH "catch"
%token<token> KW_CASE "case"
%token<token> KW_SET "set"
%token<token> KW_VOID "void"
%token<token> KW_STATIC
%token<token> KW_INSTANCEOF "instanceof"
%token<token> KW_IMPORT "import"
%token<token> KW_RETURN "return"
%token<token> KW_TYPEOF "typeof"
%token<token> KW_INTERFACE "interface"
%token<token> KW_NULL "null"
%token<token> KW_VAR "var"
%token<token> KW_DYNAMIC "dynamic"
%token<token> KW_OVERRIDE
%token<token> KW_FINAL
%token<token> KW_EACH "each"
%token<token> KW_GET "get"
%token<token> KW_TRY "try"
%token<token> KW_SUPER "super"
%token<token> KW_EXTENDS
%token<token> KW_FALSE "false"
%token<token> KW_TRUE "true"
%token<token> KW_BOOLEAN "Boolean"
%token<token> KW_UINT "uint"
%token<token> KW_INT "int"
%token<token> KW_NUMBER "Number"
%token<token> KW_STRING "String"
%token<token> KW_DEFAULT "default"
%token<token> KW_DELETE "delete"
%token<token> KW_IF "if"
%token<token> KW_ELSE  "else"
%token<token> KW_BREAK   "break"
%token<token> KW_IS "is"
%token<token> KW_IN "in"
%token<token> KW_AS "as"

%token<token> T_EQEQ "=="
%token<token> T_EQEQEQ "==="
%token<token> T_NE "!="
%token<token> T_NEE "!=="
%token<token> T_LE "<="
%token<token> T_GE ">="
%token<token> T_DIVBY "/=" 
%token<token> T_MODBY "%="
%token<token> T_MULBY "*="
%token<token> T_PLUSBY "+=" 
%token<token> T_MINUSBY "-="
%token<token> T_SHRBY ">>="
%token<token> T_SHLBY "<<="
%token<token> T_USHRBY ">>>="
%token<token> T_OROR "||"
%token<token> T_ANDAND "&&"
%token<token> T_COLONCOLON "::"
%token<token> T_MINUSMINUS "--"
%token<token> T_PLUSPLUS "++"
%token<token> T_DOTDOT ".."
%token<token> T_DOTDOTDOT "..."
%token<token> T_SHL "<<"
%token<token> T_USHR ">>>"
%token<token> T_SHR ">>"

%type <for_start> FOR_START
%type <id> X_IDENTIFIER PACKAGE FOR_IN_INIT
%type <token> VARCONST
%type <code> CODE
%type <code> CODEPIECE
%type <code> CODEBLOCK MAYBECODE MAYBE_CASE_LIST CASE_LIST DEFAULT CASE SWITCH
%type <token> PACKAGE_DECLARATION
%type <token> FUNCTION_DECLARATION
%type <code> VARIABLE_DECLARATION ONE_VARIABLE VARIABLE_LIST
%type <token> CLASS_DECLARATION
%type <token> NAMESPACE_DECLARATION
%type <token> INTERFACE_DECLARATION
%type <code> VOIDEXPRESSION
%type <value> EXPRESSION NONCOMMAEXPRESSION
%type <value> MAYBEEXPRESSION
%type <value> E DELETE
%type <value> CONSTANT
%type <code> FOR FOR_IN IF WHILE DO_WHILE MAYBEELSE BREAK RETURN CONTINUE
%type <token> USE_NAMESPACE
%type <code> FOR_INIT
%type <token> IMPORT
%type <classinfo> MAYBETYPE
%type <token> GETSET
%type <param> PARAM
%type <params> PARAM_LIST
%type <params> MAYBE_PARAM_LIST
%type <flags> MAYBE_MODIFIERS
%type <flags> MODIFIER_LIST
%type <constant> STATICCONSTANT MAYBESTATICCONSTANT
%type <classinfo_list> IMPLEMENTS_LIST
%type <classinfo> EXTENDS
%type <classinfo_list> EXTENDS_LIST
%type <classinfo> CLASS PACKAGEANDCLASS QNAME
%type <classinfo_list> QNAME_LIST
%type <classinfo> TYPE
//%type <token> VARIABLE
%type <value> VAR_READ
%type <value> NEW
//%type <token> T_IDENTIFIER
%type <token> MODIFIER
%type <value> FUNCTIONCALL
%type <value_list> MAYBE_EXPRESSION_LIST EXPRESSION_LIST MAYBE_PARAM_VALUES MAYBE_EXPRPAIR_LIST EXPRPAIR_LIST

// precedence: from low to high

%left prec_none

%left below_semicolon
%left ';'
%left ','
%nonassoc below_assignment // for ?:, contrary to spec
%right '=' "*=" "/=" "%=" "+=" "-=" "<<=" ">>=" ">>>=" "&=" "^=" "|="
%right '?' ':'
%left "||"
%left "&&"
%nonassoc '|'
%nonassoc '^'
%nonassoc '&'
%nonassoc "==" "!=" "===" "!=="
%nonassoc "is" "as" "in"
%nonassoc "<=" '<' ">=" '>' "instanceof" // TODO: support "a < b < c" syntax?
%left "<<" ">>" ">>>" 
%left below_minus
%left '-' '+'
%left '/' '*' '%'
%left plusplus_prefix minusminus_prefix '~' '!' "void" "delete" "typeof" //FIXME: *unary* + - should be here, too
%left "--" "++" 
%nonassoc below_curly
%left '[' ']' '{' "new" '.' ".." "::"
%nonassoc T_IDENTIFIER
%left above_identifier
%left below_else
%nonassoc "else"
%left '('

// needed for "return" precedence:
%nonassoc T_STRING T_REGEXP
%nonassoc T_INT T_UINT T_BYTE T_SHORT T_FLOAT
%nonassoc "false" "true" "null" "undefined" "super"


     
%{

static int yyerror(char*s)
{
   syntaxerror("%s", s); 
}

static char* concat2(const char* t1, const char* t2)
{
    int l1 = strlen(t1);
    int l2 = strlen(t2);
    char*text = malloc(l1+l2+1);
    memcpy(text   , t1, l1);
    memcpy(text+l1, t2, l2);
    text[l1+l2] = 0;
    return text;
}
static char* concat3(const char* t1, const char* t2, const char* t3)
{
    int l1 = strlen(t1);
    int l2 = strlen(t2);
    int l3 = strlen(t3);
    char*text = malloc(l1+l2+l3+1);
    memcpy(text   , t1, l1);
    memcpy(text+l1, t2, l2);
    memcpy(text+l1+l2, t3, l3);
    text[l1+l2+l3] = 0;
    return text;
}

typedef struct _import {
    char*package;
} import_t;

DECLARE_LIST(import);

typedef struct _classstate {
    /* class data */
    classinfo_t*info;
    abc_class_t*abc;
    code_t*init;
    code_t*static_init;
    char has_constructor;
} classstate_t;

typedef struct _methodstate {
    /* method data */
    memberinfo_t*info;
    char late_binding;
    /* code that needs to be executed at the start of
       a method (like initializing local registers) */
    code_t*initcode;
    char is_constructor;
    char has_super;
    char is_global;
} methodstate_t;

typedef struct _state {
    struct _state*old;
    int level;

    char*package;     
    import_list_t*wildcard_imports;
    dict_t*imports;
    char has_own_imports;
  
    classstate_t*cls;   
    methodstate_t*method;
    
    dict_t*vars;
} state_t;

typedef struct _global {
    abc_file_t*file;
    abc_script_t*init;

    int variable_count;
} global_t;

static global_t*global = 0;
static state_t* state = 0;

DECLARE_LIST(state);

#define MULTINAME(m,x) \
    multiname_t m;\
    namespace_t m##_ns;\
    registry_fill_multiname(&m, &m##_ns, x);
                    
#define MEMBER_MULTINAME(m,f,n) \
    multiname_t m;\
    namespace_t m##_ns;\
    if(f) { \
        m##_ns.access = flags2access(f->flags); \
        m##_ns.name = ""; \
        m.type = QNAME; \
        m.ns = &m##_ns; \
        m.namespace_set = 0; \
        m.name = f->name; \
    } else { \
        m.type = MULTINAME; \
        m.ns =0; \
        m.namespace_set = &nopackage_namespace_set; \
        m.name = n; \
    }

/* warning: list length of namespace set is undefined */
#define MULTINAME_LATE(m, access, package) \
    namespace_t m##_ns = {access, package}; \
    namespace_set_t m##_nsset; \
    namespace_list_t m##_l;m##_l.next = 0; \
    m##_nsset.namespaces = &m##_l; \
    m##_nsset = m##_nsset; \
    m##_l.namespace = &m##_ns; \
    multiname_t m = {MULTINAMEL, 0, &m##_nsset, 0};

static namespace_t ns1 = {ACCESS_PRIVATE, ""};
static namespace_t ns2 = {ACCESS_PROTECTED, ""};
static namespace_t ns3 = {ACCESS_PACKAGEINTERNAL, ""};
static namespace_t ns4 = {ACCESS_PACKAGE, ""};
static namespace_list_t nl4 = {&ns4,0};
static namespace_list_t nl3 = {&ns3,&nl4};
static namespace_list_t nl2 = {&ns2,&nl3};
static namespace_list_t nl1 = {&ns1,&nl2};
static namespace_set_t nopackage_namespace_set = {&nl1};

static void init_globals()
{
    global = rfx_calloc(sizeof(global_t));
}

static void new_state()
{
    NEW(state_t, s);
    state_t*oldstate = state;
    if(state)
        memcpy(s, state, sizeof(state_t)); //shallow copy
    if(!s->imports) {
        s->imports = dict_new();
    }
    state = s;
    state->level++;
    state->has_own_imports = 0;    
    state->vars = dict_new();
    state->old = oldstate;
}
static void state_has_imports()
{
    state->wildcard_imports = list_clone(state->wildcard_imports);
    state->imports = dict_clone(state->imports);
    state->has_own_imports = 1;
}

static void state_destroy(state_t*state)
{
    if(state->has_own_imports) {
        list_free(state->wildcard_imports);
        dict_destroy(state->imports);state->imports=0;
    }
    if(state->imports && (!state->old || state->old->imports!=state->imports)) {
        dict_destroy(state->imports);state->imports=0;
    }
    if(state->vars) {
        int t;
        for(t=0;t<state->vars->hashsize;t++) {
            dictentry_t*e =state->vars->slots[t];
            while(e) {
                free(e->data);e->data=0;
                e = e->next;
            }
        }
        dict_destroy(state->vars);state->vars=0;
    }
    
    free(state);
}

static void old_state()
{
    if(!state || !state->old)
        syntaxerror("invalid nesting");
    state_t*leaving = state;
    state = state->old;
    /*if(state->method->initcode) {
        printf("residual initcode\n");
        code_dump(state->method->initcode, 0, 0, "", stdout);
    }*/
    state_destroy(leaving);
}
void initialize_state()
{
    init_globals();
    new_state();

    global->file = abc_file_new();
    global->file->flags &= ~ABCFILE_LAZY;
    
    global->init = abc_initscript(global->file, 0);
    code_t*c = global->init->method->body->code;

    c = abc_getlocal_0(c);
    c = abc_pushscope(c);
  
    /* findpropstrict doesn't just return a scope object- it
       also makes it "active" somehow. Push local_0 on the
       scope stack and read it back with findpropstrict, it'll
       contain properties like "trace". Trying to find the same
       property on a "vanilla" local_0 yields only a "undefined" */
    //c = abc_findpropstrict(c, "[package]::trace");
    
    /*c = abc_getlocal_0(c);
    c = abc_findpropstrict(c, "[package]::trace");
    c = abc_coerce_a(c);
    c = abc_setlocal_1(c);

    c = abc_pushbyte(c, 0);
    c = abc_setlocal_2(c);
   
    code_t*xx = c = abc_label(c);
    c = abc_findpropstrict(c, "[package]::trace");
    c = abc_pushstring(c, "prop:");
    c = abc_hasnext2(c, 1, 2);
    c = abc_dup(c);
    c = abc_setlocal_3(c);
    c = abc_callpropvoid(c, "[package]::trace", 2);
    c = abc_getlocal_3(c);
    c = abc_kill(c, 3);
    c = abc_iftrue(c,xx);*/

    c = abc_findpropstrict(c, "[package]::trace");
    c = abc_pushstring(c, "[entering global init function]");
    c = abc_callpropvoid(c, "[package]::trace", 1);
    
    global->init->method->body->code = c;
}
void* finalize_state()
{
    if(state->level!=1) {
        syntaxerror("unexpected end of file");
    }
    abc_method_body_t*m = global->init->method->body;
    //__ popscope(m);
    
    __ findpropstrict(m, "[package]::trace");
    __ pushstring(m, "[leaving global init function]");
    __ callpropvoid(m, "[package]::trace", 1);
    __ returnvoid(m);

    state_destroy(state);

    return global->file;
}


static void startpackage(char*name)
{
    if(state->package) {
        syntaxerror("Packages can not be nested."); 
    } 
    new_state();
    /*printf("entering package \"%s\"\n", name);*/
    state->package = strdup(name);
}
static void endpackage()
{
    /*printf("leaving package \"%s\"\n", state->package);*/

    //used e.g. in classinfo_register:
    //free(state->package);state->package=0;

    old_state();
}

char*globalclass=0;
static void startclass(int flags, char*classname, classinfo_t*extends, classinfo_list_t*implements, char interface)
{
    if(state->cls) {
        syntaxerror("inner classes now allowed"); 
    }
    new_state();
    state->cls = rfx_calloc(sizeof(classstate_t));

    token_list_t*t=0;
    classinfo_list_t*mlist=0;
    /*printf("entering class %s\n", name);
    printf("  modifiers: ");for(t=modifiers->tokens;t;t=t->next) printf("%s ", t->token);printf("\n");
    if(extends) 
        printf("  extends: %s.%s\n", extends->package, extends->name);
    printf("  implements (%d): ", list_length(implements));
    for(mlist=implements;mlist;mlist=mlist->next)  {
        printf("%s ", mlist->classinfo?mlist->classinfo->name:0);
    }
    printf("\n");
    */

    if(flags&~(FLAG_INTERNAL|FLAG_PUBLIC|FLAG_FINAL|FLAG_DYNAMIC))
        syntaxerror("invalid modifier(s)");

    if((flags&(FLAG_PUBLIC|FLAG_INTERNAL)) == (FLAG_PUBLIC|FLAG_INTERNAL))
        syntaxerror("public and internal not supported at the same time.");

    /* create the class name, together with the proper attributes */
    int access=0;
    char*package=0;

    if(!(flags&FLAG_PUBLIC) && !state->package) {
        access = ACCESS_PRIVATE; package = current_filename;
    } else if(!(flags&FLAG_PUBLIC) && state->package) {
        access = ACCESS_PACKAGEINTERNAL; package = state->package;
    } else if(state->package) {
        access = ACCESS_PACKAGE; package = state->package;
    } else {
        syntaxerror("public classes only allowed inside a package");
    }

    if(registry_findclass(package, classname)) {
        syntaxerror("Package \"%s\" already contains a class called \"%s\"", package, classname);
    }
   

    /* build info struct */
    int num_interfaces = (list_length(implements));
    state->cls->info = classinfo_register(access, package, classname, num_interfaces);
    state->cls->info->superclass = extends?extends:TYPE_OBJECT;
    int pos = 0;
    classinfo_list_t*l = implements;
    for(l=implements;l;l=l->next) {
        state->cls->info->interfaces[pos++] = l->classinfo;
    }
    
    multiname_t*extends2 = sig2mname(extends);

    MULTINAME(classname2,state->cls->info);

    /*if(extends) {
        state->cls_init = abc_getlocal_0(state->cls_init);
        state->cls_init = abc_constructsuper(state->cls_init, 0);
    }*/

    state->cls->abc = abc_class_new(global->file, &classname2, extends2);
    if(flags&FLAG_FINAL) abc_class_final(state->cls->abc);
    if(!(flags&FLAG_DYNAMIC)) abc_class_sealed(state->cls->abc);
    if(interface) {
        state->cls->info->flags |= CLASS_INTERFACE;
        abc_class_interface(state->cls->abc);
    }

    abc_class_protectedNS(state->cls->abc, classname);

    for(mlist=implements;mlist;mlist=mlist->next) {
        MULTINAME(m, mlist->classinfo);
        abc_class_add_interface(state->cls->abc, &m);
    }

    /* now write the construction code for this class */
    int slotindex = abc_initscript_addClassTrait(global->init, &classname2, state->cls->abc);

    abc_method_body_t*m = global->init->method->body;
    __ getglobalscope(m);
    classinfo_t*s = extends;

    int count=0;
    
    while(s) {
        //TODO: take a look at the current scope stack, maybe 
        //      we can re-use something
        s = s->superclass;
        if(!s) 
        break;
       
        multiname_t*s2 = sig2mname(s);
        __ getlex2(m, s2);
        multiname_destroy(s2);

        __ pushscope(m); count++;
        m->code = m->code->prev->prev; // invert
    }
    /* continue appending after last op end */
    while(m->code && m->code->next) m->code = m->code->next; 

    /* TODO: if this is one of *our* classes, we can also 
             do a getglobalscope/getslot <nr> (which references
             the init function's slots) */
    if(extends2) {
        __ getlex2(m, extends2);
        __ dup(m);
        /* notice: we get a Verify Error #1107 if the top elemnt on the scope
           stack is not the superclass */
        __ pushscope(m);count++;
    } else {
        __ pushnull(m);
        /* notice: we get a verify error #1107 if the top element on the scope 
           stack is not the global object */
        __ getlocal_0(m);
        __ pushscope(m);count++;
    }
    __ newclass(m,state->cls->abc);
    while(count--) {
        __ popscope(m);
    }
    __ setslot(m, slotindex);

    /* flash.display.MovieClip handling */
    if(!globalclass && (flags&FLAG_PUBLIC) && classinfo_equals(registry_getMovieClip(),extends)) {
        if(state->package && state->package[0]) {
            globalclass = concat3(state->package, ".", classname);
        } else {
            globalclass = strdup(classname);
        }
    }
    multiname_destroy(extends2);
}

static code_t* wrap_function(code_t*c,code_t*initcode, code_t*body)
{
    c = code_append(c, initcode);
    c = code_append(c, body);
    /* append return if necessary */
    if(!c || c->opcode != OPCODE_RETURNVOID && 
             c->opcode != OPCODE_RETURNVALUE) {
        c = abc_returnvoid(c);
    }
    return c;
}

static void endclass()
{
    if(!state->cls->has_constructor && !(state->cls->info->flags&CLASS_INTERFACE)) {
        code_t*c = 0;
        c = abc_getlocal_0(c);
        c = abc_constructsuper(c, 0);
        state->cls->init = code_append(state->cls->init, c);
    }

    if(state->cls->init) {
        abc_method_t*m = abc_class_getconstructor(state->cls->abc, 0);
        m->body->code = wrap_function(0, state->cls->init, m->body->code);
    }
    if(state->cls->static_init) {
        abc_method_t*m = abc_class_getstaticconstructor(state->cls->abc, 0);
        m->body->code = wrap_function(0, state->cls->static_init, m->body->code);
    } else {
        // handy for scope testing 
        /*code_t*c = 0;
        c = abc_pop(c);
        c = abc_pop(c);
        abc_class_getstaticconstructor(state->cls->abc,0)->body->code = c;*/
    }

    free(state->cls);state->cls=0;
    old_state();
}

typedef struct _variable {
    int index;
    classinfo_t*type;
} variable_t;

static variable_t* find_variable(char*name)
{
    state_t* s = state;
    while(s) {
        variable_t*v = 0;
        if(s->method)
            v = dict_lookup(s->vars, name);
        if(v) {
            return v;
        }
        s = s->old;
    }
    return 0;
} 
static variable_t* find_variable_safe(char*name)
{
    variable_t* v = find_variable(name);
    if(!v)
        syntaxerror("undefined variable: %s", name);
    return v;
}
static char variable_exists(char*name) 
{
    return dict_lookup(state->vars, name)!=0;
}
code_t*defaultvalue(code_t*c, classinfo_t*type);
static int new_variable(char*name, classinfo_t*type, char init)
{
    NEW(variable_t, v);
    v->index = global->variable_count;
    v->type = type;
    dict_put(state->vars, name, v);

    if(init && state->method && type) {
        /* if this is a typed variable:
           push default value for type on stack at the very beginning of the
           method, so that it always has that type regardless of the control
           path */
        state->method->initcode = defaultvalue(state->method->initcode, type);
        state->method->initcode = abc_setlocal(state->method->initcode, v->index);
    }
    return global->variable_count++;
}
#define TEMPVARNAME "__as3_temp__"
static int gettempvar()
{
    variable_t*v = find_variable(TEMPVARNAME);
    if(v) 
        return v->index;
    return new_variable(TEMPVARNAME, 0, 0);
}

code_t* killvars(code_t*c) 
{
    int t;
    for(t=0;t<state->vars->hashsize;t++) {
        dictentry_t*e =state->vars->slots[t];
        while(e) {
            variable_t*v = (variable_t*)e->data;
            //do this always, otherwise register types don't match
            //in the verifier when doing nested loops
            //if(!TYPE_IS_BUILTIN_SIMPLE(type)) {
            c = abc_kill(c, v->index); 
            e = e->next;
        }
    }
    return c;
}

void check_code_for_break(code_t*c)
{
    while(c) {
        if(c->opcode == OPCODE___BREAK__) {
            char*name = string_cstr(c->data[0]);
            syntaxerror("Unresolved \"break %s\"", name);
        }
        if(c->opcode == OPCODE___CONTINUE__) {
            char*name = string_cstr(c->data[0]);
            syntaxerror("Unresolved \"continue %s\"", name);
        }
        c=c->prev;
    }
}


static void check_constant_against_type(classinfo_t*t, constant_t*c)
{
#define xassert(b) if(!(b)) syntaxerror("Invalid default value %s for type '%s'", constant_tostring(c), t->name)
   if(TYPE_IS_NUMBER(t)) {
        xassert(c->type == CONSTANT_FLOAT
             || c->type == CONSTANT_INT
             || c->type == CONSTANT_UINT);
   } else if(TYPE_IS_UINT(t)) {
        xassert(c->type == CONSTANT_UINT ||
               (c->type == CONSTANT_INT && c->i>0));
   } else if(TYPE_IS_INT(t)) {
        xassert(c->type == CONSTANT_INT);
   } else if(TYPE_IS_BOOLEAN(t)) {
        xassert(c->type == CONSTANT_TRUE
             || c->type == CONSTANT_FALSE);
   }
}

static int flags2access(int flags)
{
    int access = 0;
    if(flags&FLAG_PUBLIC)  {
        if(access&(FLAG_PRIVATE|FLAG_PROTECTED|FLAG_INTERNAL)) syntaxerror("invalid combination of access levels");
        access = ACCESS_PACKAGE;
    } else if(flags&FLAG_PRIVATE) {
        if(access&(FLAG_PUBLIC|FLAG_PROTECTED|FLAG_INTERNAL)) syntaxerror("invalid combination of access levels");
        access = ACCESS_PRIVATE;
    } else if(flags&FLAG_PROTECTED) {
        if(access&(FLAG_PUBLIC|FLAG_PRIVATE|FLAG_INTERNAL)) syntaxerror("invalid combination of access levels");
        access = ACCESS_PROTECTED;
    } else {
        access = ACCESS_PACKAGEINTERNAL;
    }
    return access;
}

static memberinfo_t*registerfunction(enum yytokentype getset, int flags, char*name, params_t*params, classinfo_t*return_type, int slot)
{
    memberinfo_t*minfo = 0;
    if(!state->cls) {
        //package method
        minfo = rfx_calloc(sizeof(memberinfo_t));
        classinfo_t*c = classinfo_register(flags2access(flags), state->package, name, 0);
        c->flags |= FLAG_METHOD;
        c->function = minfo;
        minfo->kind = MEMBER_METHOD;
        minfo->name = name;
        minfo->flags = FLAG_STATIC;
        minfo->return_type = return_type;
    } else if(getset != KW_GET && getset != KW_SET) {
        //class method
        if((minfo = registry_findmember(state->cls->info, name, 0))) {
            if(minfo->parent == state->cls->info) {
                syntaxerror("class already contains a member/method called '%s'", name);
            } else if(!minfo->parent) {
                syntaxerror("internal error: overriding method %s, which doesn't have parent", name);
            } else {
                if(!(minfo->flags&(FLAG_STATIC|FLAG_PRIVATE)))
                    syntaxerror("function %s already exists in superclass. Did you forget the 'override' keyword?");
            }
        }
        minfo = memberinfo_register(state->cls->info, name, MEMBER_METHOD);
        minfo->return_type = return_type;
        // getslot on a member slot only returns "undefined", so no need
        // to actually store these
        //state->minfo->slot = state->method->abc->method->trait->slot_id;
    } else {
        //class getter/setter
        int gs = getset==KW_GET?MEMBER_GET:MEMBER_SET;
        classinfo_t*type=0;
        if(getset == KW_GET)
            type = return_type;
        else if(params->list)
            type = params->list->param->type;
        // not sure wether to look into superclasses here, too
        if((minfo=registry_findmember(state->cls->info, name, 0))) {
            if(minfo->kind & ~(MEMBER_GET|MEMBER_SET))
                syntaxerror("class already contains a member or method called '%s'", name);
            if(minfo->kind & gs)
                syntaxerror("getter/setter for '%s' already defined", name);
            /* make a setter or getter into a getset */
            minfo->kind |= gs;
            if(!minfo->type) 
                minfo->type = type;
            else
                if(type && minfo->type != type)
                    syntaxerror("different type in getter and setter");
        } else {
            minfo = memberinfo_register(state->cls->info, name, gs);
            minfo->type = type;
        }
        /* can't assign a slot as getter and setter might have different slots */
        //minfo->slot = slot;
    }
    if(flags&FLAG_STATIC) minfo->flags |= FLAG_STATIC;
    if(flags&FLAG_PUBLIC) minfo->flags |= FLAG_PUBLIC;
    if(flags&FLAG_PRIVATE) minfo->flags |= FLAG_PRIVATE;
    if(flags&FLAG_PROTECTED) minfo->flags |= FLAG_PROTECTED;
    if(flags&FLAG_INTERNAL) minfo->flags |= FLAG_INTERNAL;
    if(flags&FLAG_OVERRIDE) minfo->flags |= FLAG_OVERRIDE;
    return minfo;
}

static void startfunction(token_t*ns, int flags, enum yytokentype getset, char*name,
                          params_t*params, classinfo_t*return_type)
{
    if(state->method) {
        syntaxerror("not able to start another method scope");
    }
    new_state();
    global->variable_count = 0;
    state->method = rfx_calloc(sizeof(methodstate_t));
    state->method->initcode = 0;
    state->method->has_super = 0;
    if(state->cls) {
        state->method->is_constructor = !strcmp(state->cls->info->name,name);
        state->cls->has_constructor |= state->method->is_constructor;
        
        new_variable((flags&FLAG_STATIC)?"class":"this", state->cls->info, 0);
    } else {
        state->method->is_global = 1;
        state->method->late_binding = 1; // for global methods, always push local_0 on the scope stack

        new_variable("globalscope", 0, 0);
    }

    /* state->vars is initialized by state_new */

    param_list_t*p=0;
    for(p=params->list;p;p=p->next) {
        new_variable(p->param->name, p->param->type, 0);
    }
    if(state->method->is_constructor)
        name = "__as3_constructor__";
    state->method->info = registerfunction(getset, flags, name, params, return_type, 0);
}

static void endfunction(token_t*ns, int flags, enum yytokentype getset, char*name,
                          params_t*params, classinfo_t*return_type, code_t*body)
{
    abc_method_t*f = 0;

    multiname_t*type2 = sig2mname(return_type);
    int slot = 0;
    if(state->method->is_constructor) {
        f = abc_class_getconstructor(state->cls->abc, type2);
    } else if(!state->method->is_global) {
        namespace_t mname_ns = {flags2access(flags), ""};
        multiname_t mname = {QNAME, &mname_ns, 0, name};

        if(flags&FLAG_STATIC)
            f = abc_class_staticmethod(state->cls->abc, type2, &mname);
        else
            f = abc_class_method(state->cls->abc, type2, &mname);
        slot = f->trait->slot_id;
    } else {
        namespace_t mname_ns = {flags2access(flags), state->package};
        multiname_t mname = {QNAME, &mname_ns, 0, name};

        f = abc_method_new(global->file, type2, 1);
        trait_t*t = trait_new_method(&global->init->traits, multiname_clone(&mname), f);
        //abc_code_t*c = global->init->method->body->code;
    }
    //flash doesn't seem to allow us to access function slots
    //state->method->info->slot = slot;

    if(flags&FLAG_OVERRIDE) f->trait->attributes |= TRAIT_ATTR_OVERRIDE;
    if(getset == KW_GET) f->trait->kind = TRAIT_GETTER;
    if(getset == KW_SET) f->trait->kind = TRAIT_SETTER;
    if(params->varargs) f->flags |= METHOD_NEED_REST;

    char opt=0;
    param_list_t*p=0;
    for(p=params->list;p;p=p->next) {
        if(params->varargs && !p->next) {
            break; //varargs: omit last parameter in function signature
        }
        multiname_t*m = sig2mname(p->param->type);
	list_append(f->parameters, m);
        if(p->param->value) {
            check_constant_against_type(p->param->type, p->param->value);
            opt=1;list_append(f->optional_parameters, p->param->value);
        } else if(opt) {
            syntaxerror("non-optional parameter not allowed after optional parameters");
        }
    }
    check_code_for_break(body);

    if(f->body)
        f->body->code = body;
    else //interface
        if(body)
            syntaxerror("interface methods can't have a method body");
       
    free(state->method);state->method=0;
    old_state();
}



char is_subtype_of(classinfo_t*type, classinfo_t*supertype)
{
    return 1; // FIXME
}

void breakjumpsto(code_t*c, char*name, code_t*jump) 
{
    while(c) {
        if(c->opcode == OPCODE___BREAK__) {
            string_t*name2 = c->data[0];
            if(!name2->len || !strncmp(name2->str, name, name2->len)) {
                c->opcode = OPCODE_JUMP;
                c->branch = jump;
            }
        }
        c=c->prev;
    }
}
void continuejumpsto(code_t*c, char*name, code_t*jump) 
{
    while(c) {
        if(c->opcode == OPCODE___CONTINUE__) {
            string_t*name2 = c->data[0];
            if(!name2->len || !strncmp(name2->str, name, name2->len)) {
                c->opcode = OPCODE_JUMP;
                c->branch = jump;
            }
        }
        c = c->prev;
    }
}

classinfo_t*join_types(classinfo_t*type1, classinfo_t*type2, char op)
{
    if(!type1 || !type2) 
        return registry_getanytype();
    if(TYPE_IS_ANY(type1) || TYPE_IS_ANY(type2))
        return registry_getanytype();
    if(type1 == type2)
        return type1;
    return registry_getanytype();
}
code_t*converttype(code_t*c, classinfo_t*from, classinfo_t*to)
{
    if(from==to)
        return c;
    if(!to) {
        return abc_coerce_a(c);
    }
    MULTINAME(m, to);
    if(!from) {
        // cast an "any" type to a specific type. subject to
        // runtime exceptions
        return abc_coerce2(c, &m);
    }
    
    if((TYPE_IS_NUMBER(from) || TYPE_IS_UINT(from) || TYPE_IS_INT(from)) &&
       (TYPE_IS_NUMBER(to) || TYPE_IS_UINT(to) || TYPE_IS_INT(to))) {
        // allow conversion between number types
        return abc_coerce2(c, &m);
    }
    //printf("%s.%s\n", from.package, from.name);
    //printf("%s.%s\n", to.package, to.name);

    classinfo_t*supertype = from;
    while(supertype) {
        if(supertype == to) {
             // target type is one of from's superclasses
             return abc_coerce2(c, &m);
        }
        int t=0;
        while(supertype->interfaces[t]) {
            if(supertype->interfaces[t]==to) {
                // target type is one of from's interfaces
                return abc_coerce2(c, &m);
            }
            t++;
        }
        supertype = supertype->superclass;
    }
    if(TYPE_IS_FUNCTION(from) && TYPE_IS_FUNCTION(to))
        return c;
    if(TYPE_IS_CLASS(from) && TYPE_IS_CLASS(to))
        return c;
    syntaxerror("can't convert type %s to %s", from->name, to->name);
}

code_t*defaultvalue(code_t*c, classinfo_t*type)
{
    if(TYPE_IS_INT(type)) {
       c = abc_pushbyte(c, 0);
    } else if(TYPE_IS_UINT(type)) {
       c = abc_pushuint(c, 0);
    } else if(TYPE_IS_FLOAT(type)) {
       c = abc_pushnan(c);
    } else if(TYPE_IS_BOOLEAN(type)) {
       c = abc_pushfalse(c);
    } else {
       c = abc_pushnull(c);
    }
    return c;
}

char is_pushundefined(code_t*c)
{
    return (c && !c->prev && !c->next && c->opcode == OPCODE_PUSHUNDEFINED);
}

void parserassert(int b)
{
    if(!b) syntaxerror("internal error: assertion failed");
}

static classinfo_t* find_class(char*name)
{
    classinfo_t*c=0;

    c = registry_findclass(state->package, name);

    /* try explicit imports */
    dictentry_t* e = dict_get_slot(state->imports, name);
    while(e) {
        if(c)
            break;
        if(!strcmp(e->key, name)) {
            c = (classinfo_t*)e->data;
        }
        e = e->next;
    }

    /* try package.* imports */
    import_list_t*l = state->wildcard_imports;
    while(l) {
        if(c)
            break;
        //printf("does package %s contain a class %s?\n", l->import->package, name);
        c = registry_findclass(l->import->package, name);
        l = l->next;
    }

    /* try global package */
    if(!c) {
        c = registry_findclass("", name);
    }
    return c;
}

static code_t* toreadwrite(code_t*in, code_t*middlepart, char justassign, char readbefore)
{
    /* converts this:

       [prefix code] [read instruction]

       to this:

       [prefix code] ([dup]) [read instruction] [middlepart] [setvar] [write instruction] [getvar]
    */
    
    if(in && in->opcode == OPCODE_COERCE_A) {
        in = code_cutlast(in);
    }
    if(in->next)
        syntaxerror("internal error");

    /* chop off read instruction */
    code_t*prefix = in;
    code_t*r = in;
    if(r->prev) {
        prefix = r->prev;r->prev = 0;
        prefix->next=0;
    } else {
        prefix = 0;
    }

    char use_temp_var = readbefore;

    /* generate the write instruction, and maybe append a dup to the prefix code */
    code_t* write = abc_nop(0);
    if(r->opcode == OPCODE_GETPROPERTY) {
        write->opcode = OPCODE_SETPROPERTY;
        multiname_t*m = (multiname_t*)r->data[0];
        write->data[0] = multiname_clone(m);
        if(m->type == QNAME || m->type == MULTINAME) {
            if(!justassign) {
                prefix = abc_dup(prefix); // we need the object, too
            }
            use_temp_var = 1;
        } else if(m->type == MULTINAMEL) {
            if(!justassign) {
                /* dupping two values on the stack requires 5 operations and one register- 
                   couldn't adobe just have given us a dup2? */
                int temp = gettempvar();
                prefix = abc_setlocal(prefix, temp);
                prefix = abc_dup(prefix);
                prefix = abc_getlocal(prefix, temp);
                prefix = abc_swap(prefix);
                prefix = abc_getlocal(prefix, temp);
                if(!use_temp_var);
                    prefix = abc_kill(prefix, temp);
            }
            use_temp_var = 1;
        } else {
            syntaxerror("illegal lvalue: can't assign a value to this expression (not a qname/multiname)");
        }
    } else if(r->opcode == OPCODE_GETSLOT) {
        write->opcode = OPCODE_SETSLOT;
        write->data[0] = r->data[0];
        if(!justassign) {
            prefix = abc_dup(prefix); // we need the object, too
        }
        use_temp_var = 1;
    } else if(r->opcode == OPCODE_GETLOCAL) { 
        write->opcode = OPCODE_SETLOCAL;
        write->data[0] = r->data[0];
    } else if(r->opcode == OPCODE_GETLOCAL_0) { 
        write->opcode = OPCODE_SETLOCAL_0;
    } else if(r->opcode == OPCODE_GETLOCAL_1) { 
        write->opcode = OPCODE_SETLOCAL_1;
    } else if(r->opcode == OPCODE_GETLOCAL_2) { 
        write->opcode = OPCODE_SETLOCAL_2;
    } else if(r->opcode == OPCODE_GETLOCAL_3) { 
        write->opcode = OPCODE_SETLOCAL_3;
    } else {
        code_dump(r, 0, 0, "", stdout);
        syntaxerror("illegal lvalue: can't assign a value to this expression");
    }
    code_t* c = 0;
    
    int temp = -1;
    if(!justassign) {
        if(use_temp_var) {
            /* with getproperty/getslot, we have to be extra careful not
               to execute the read code twice, as it might have side-effects
               (e.g. if the property is in fact a setter/getter combination)

               So read the value, modify it, and write it again,
               using prefix only once and making sure (by using a temporary
               register) that the return value is what we just wrote */
            temp = gettempvar();
            c = code_append(c, prefix);
            c = code_append(c, r);
            if(readbefore) {
                c = abc_dup(c);
                c = abc_setlocal(c, temp);
            }
            c = code_append(c, middlepart);
            if(!readbefore) {
                c = abc_dup(c);
                c = abc_setlocal(c, temp);
            }
            c = code_append(c, write);
            c = abc_getlocal(c, temp);
            c = abc_kill(c, temp);
        } else {
            /* if we're allowed to execute the read code twice *and*
               the middlepart doesn't modify the code, things are easier.
            */
            code_t* r2 = code_dup(r);
            //c = code_append(c, prefix);
            parserassert(!prefix);
            c = code_append(c, r);
            c = code_append(c, middlepart);
            c = code_append(c, write);
            c = code_append(c, r2);
        }
    } else {
        /* even smaller version: overwrite the value without reading
           it out first */
        if(!use_temp_var) {
            if(prefix) {
                c = code_append(c, prefix);
                c = abc_dup(c);
            }
            c = code_append(c, middlepart);
            c = code_append(c, write);
            c = code_append(c, r);
        } else {
            temp = gettempvar();
            if(prefix) {
                c = code_append(c, prefix);
            }
            c = code_append(c, middlepart);
            c = abc_dup(c);
            c = abc_setlocal(c, temp);
            c = code_append(c, write);
            c = abc_getlocal(c, temp);
            c = abc_kill(c, temp);
        }
    }

    return c;
}

#define IS_INT(a) (TYPE_IS_INT((a).t) || TYPE_IS_UINT((a).t))
#define BOTH_INT(a,b) (IS_INT(a) && IS_INT(b))

%}


%%

/* ------------ code blocks / statements ---------------- */

PROGRAM: MAYBECODE {
    /* todo: do something with this code if we're outside a function */
    if($1)
        warning("ignored code");
}

MAYBECODE: CODE {$$=$1;}
MAYBECODE: {$$=code_new();}

CODE: CODE CODEPIECE {
    $$=code_append($1,$2);
}
CODE: CODEPIECE {
    $$=$1;
}

CODEPIECE: PACKAGE_DECLARATION   {$$=code_new();/*enters a scope*/}
CODEPIECE: CLASS_DECLARATION     {$$=code_new();/*enters a scope*/}
CODEPIECE: FUNCTION_DECLARATION  {$$=code_new();/*enters a scope*/}
CODEPIECE: INTERFACE_DECLARATION {$$=code_new();}
CODEPIECE: IMPORT                {$$=code_new();/*adds imports to current scope*/}
CODEPIECE: ';'                   {$$=code_new();}
CODEPIECE: VARIABLE_DECLARATION  {$$=$1}
CODEPIECE: VOIDEXPRESSION        {$$=$1}
CODEPIECE: FOR                   {$$=$1}
CODEPIECE: FOR_IN                {$$=$1}
CODEPIECE: WHILE                 {$$=$1}
CODEPIECE: DO_WHILE              {$$=$1}
CODEPIECE: SWITCH                {$$=$1}
CODEPIECE: BREAK                 {$$=$1}
CODEPIECE: CONTINUE              {$$=$1}
CODEPIECE: RETURN                {$$=$1}
CODEPIECE: IF                    {$$=$1}
CODEPIECE: NAMESPACE_DECLARATION {/*TODO*/$$=code_new();}
CODEPIECE: USE_NAMESPACE         {/*TODO*/$$=code_new();}

CODEBLOCK :  '{' CODE '}' {$$=$2;}
CODEBLOCK :  '{' '}'      {$$=0;}
CODEBLOCK :  CODEPIECE ';'             {$$=$1;}
CODEBLOCK :  CODEPIECE %prec below_semicolon {$$=$1;}

/* ------------ variables --------------------------- */

MAYBEEXPRESSION : '=' NONCOMMAEXPRESSION {$$=$2;}
                |                {$$.c=abc_pushundefined(0);
                                  $$.t=TYPE_ANY;
                                 }

VARIABLE_DECLARATION : "var" VARIABLE_LIST {$$=$2;}
VARIABLE_DECLARATION : "const" VARIABLE_LIST {$$=$2;}

VARIABLE_LIST: ONE_VARIABLE                   {$$ = $1;}
VARIABLE_LIST: VARIABLE_LIST ',' ONE_VARIABLE {$$ = code_append($1, $3);}

ONE_VARIABLE: T_IDENTIFIER MAYBETYPE MAYBEEXPRESSION
{
    if(variable_exists($1))
        syntaxerror("Variable %s already defined", $1);
   
    if(!is_subtype_of($3.t, $2)) {
        syntaxerror("Can't convert %s to %s", $3.t->name, 
                                              $2->name);
    }

    int index = new_variable($1, $2, 1);
    
    if($2) {
        if($3.c->prev || $3.c->opcode != OPCODE_PUSHUNDEFINED) {
            $$ = $3.c;
            $$ = converttype($$, $3.t, $2);
            $$ = abc_setlocal($$, index);
        } else {
            $$ = defaultvalue(0, $2);
            $$ = abc_setlocal($$, index);
        }
    } else {
        if($3.c->prev || $3.c->opcode != OPCODE_PUSHUNDEFINED) {
            $$ = $3.c;
            $$ = abc_coerce_a($$);
            $$ = abc_setlocal($$, index);
        } else {
            $$ = code_new();
        }
    }
    
    /* that's the default for a local register, anyway
        else {
        state->method->initcode = abc_pushundefined(state->method->initcode);
        state->method->initcode = abc_setlocal(state->method->initcode, index);
    }*/
    //printf("variable %s -> %d (%s)\n", $2->text, index, $4.t?$4.t->name:"");
}

/* ------------ control flow ------------------------- */

MAYBEELSE:  %prec below_else {$$ = code_new();}
MAYBEELSE: "else" CODEBLOCK {$$=$2;}
//MAYBEELSE: ';' "else" CODEBLOCK {$$=$3;}

IF : "if" '(' {new_state();} EXPRESSION ')' CODEBLOCK MAYBEELSE {
    $$ = code_new();
    $$ = code_append($$, $4.c);
    code_t*myjmp,*myif = $$ = abc_iffalse($$, 0);
   
    $$ = code_append($$, $6);
    if($7) {
        myjmp = $$ = abc_jump($$, 0);
    }
    myif->branch = $$ = abc_nop($$);
    if($7) {
        $$ = code_append($$, $7);
        myjmp->branch = $$ = abc_nop($$);
    }
    
    $$ = killvars($$);old_state();
}

FOR_INIT : {$$=code_new();}
FOR_INIT : VARIABLE_DECLARATION
FOR_INIT : VOIDEXPRESSION
FOR_IN_INIT : "var" T_IDENTIFIER MAYBETYPE {
    $$=$2;new_variable($2,$3,1);
}
FOR_IN_INIT : T_IDENTIFIER {
    $$=$1;
}

FOR_START : T_FOR '(' {new_state();$$.name=$1;$$.each=0;}
FOR_START : T_FOR "each" '(' {new_state();$$.name=$1;$$.each=1;}

FOR : FOR_START FOR_INIT ';' EXPRESSION ';' VOIDEXPRESSION ')' CODEBLOCK {
    if($1.each) syntaxerror("invalid syntax: ; not allowed in for each statement");
    $$ = code_new();
    $$ = code_append($$, $2);
    code_t*loopstart = $$ = abc_label($$);
    $$ = code_append($$, $4.c);
    code_t*myif = $$ = abc_iffalse($$, 0);
    $$ = code_append($$, $8);
    code_t*cont = $$ = abc_nop($$);
    $$ = code_append($$, $6);
    $$ = abc_jump($$, loopstart);
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1.name, out);
    continuejumpsto($$, $1.name, cont);
    myif->branch = out;

    $$ = killvars($$);old_state();
}

FOR_IN : FOR_START FOR_IN_INIT "in" EXPRESSION ')' CODEBLOCK {
    variable_t*var = find_variable($2);
    char*tmp1name = concat2($2, "__tmp1__");
    int it = new_variable(tmp1name, TYPE_INT, 0);
    char*tmp2name = concat2($2, "__array__");
    int array = new_variable(tmp1name, 0, 0);

    $$ = code_new();
    $$ = code_append($$, $4.c);
    $$ = abc_coerce_a($$);
    $$ = abc_setlocal($$, array);
    $$ = abc_pushbyte($$, 0);
    $$ = abc_setlocal($$, it);

    code_t*loopstart = $$ = abc_label($$);
    
    $$ = abc_hasnext2($$, array, it);
    code_t*myif = $$ = abc_iffalse($$, 0);
    $$ = abc_getlocal($$, array);
    $$ = abc_getlocal($$, it);
    if(!$1.each)
        $$ = abc_nextname($$);
    else
        $$ = abc_nextvalue($$);
    $$ = converttype($$, 0, var->type);
    $$ = abc_setlocal($$, var->index);

    $$ = code_append($$, $6);
    $$ = abc_jump($$, loopstart);
    
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1.name, out);
    continuejumpsto($$, $1.name, loopstart);
    
    $$ = killvars($$);
    
    myif->branch = out;

    old_state();
    free(tmp1name);
    free(tmp2name);
}

WHILE : T_WHILE '(' {new_state();} EXPRESSION ')' CODEBLOCK {
    $$ = code_new();

    code_t*myjmp = $$ = abc_jump($$, 0);
    code_t*loopstart = $$ = abc_label($$);
    $$ = code_append($$, $6);
    code_t*cont = $$ = abc_nop($$);
    myjmp->branch = cont;
    $$ = code_append($$, $4.c);
    $$ = abc_iftrue($$, loopstart);
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1, out);
    continuejumpsto($$, $1, cont);

    $$ = killvars($$);
    old_state();
}

DO_WHILE : T_DO {new_state();} CODEBLOCK "while" '(' EXPRESSION ')' {
    $$ = code_new();
    code_t*loopstart = $$ = abc_label($$);
    $$ = code_append($$, $3);
    code_t*cont = $$ = abc_nop($$);
    $$ = code_append($$, $6.c);
    $$ = abc_iftrue($$, loopstart);
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1, out);
    continuejumpsto($$, $1, cont);
    $$ = killvars($$);
    old_state();
}

BREAK : "break" %prec prec_none {
    $$ = abc___break__(0, "");
}
BREAK : "break" T_IDENTIFIER {
    $$ = abc___break__(0, $2);
}
CONTINUE : "continue" %prec prec_none {
    $$ = abc___continue__(0, "");
}
CONTINUE : "continue" T_IDENTIFIER {
    $$ = abc___continue__(0, $2);
}

MAYBE_CASE_LIST :           {$$=0;}
MAYBE_CASE_LIST : CASE_LIST {$$=$1;}
MAYBE_CASE_LIST : DEFAULT   {$$=$1;}
MAYBE_CASE_LIST : CASE_LIST DEFAULT {$$=code_append($1,$2);}
CASE_LIST: CASE             {$$=$1}
CASE_LIST: CASE_LIST CASE   {$$=code_append($$,$2);}

CASE: "case" E ':' MAYBECODE {
    $$ = abc_dup(0);
    $$ = code_append($$, $2.c);
    code_t*j = $$ = abc_ifne($$, 0);
    $$ = code_append($$, $4);
    if($$->opcode != OPCODE___BREAK__) {
        $$ = abc___fallthrough__($$, "");
    }
    code_t*e = $$ = abc_nop($$);
    j->branch = e;
}
DEFAULT: "default" ':' MAYBECODE {
    $$ = $3;
}
SWITCH : T_SWITCH '(' {new_state();} E ')' '{' MAYBE_CASE_LIST '}' {
    $$=$4.c;
    $$ = code_append($$, $7);
    code_t*out = $$ = abc_pop($$);
    breakjumpsto($$, $1, out);
    
    code_t*c = $$,*lastblock=0;
    while(c) {
        if(c->opcode == OPCODE_IFNE) {
            if(!c->next) syntaxerror("internal error in fallthrough handling");
            lastblock=c->next;
        } else if(c->opcode == OPCODE___FALLTHROUGH__) {
            if(lastblock) {
                c->opcode = OPCODE_JUMP;
                c->branch = lastblock;
            } else {
                /* fall through end of switch */
                c->opcode = OPCODE_NOP;
            }
        }
        c=c->prev;
    }
    old_state();
}

/* ------------ packages and imports ---------------- */

X_IDENTIFIER: T_IDENTIFIER
            | "package" {$$="package";}

PACKAGE: PACKAGE '.' X_IDENTIFIER {$$ = concat3($1,".",$3);free($1);$1=0;}
PACKAGE: X_IDENTIFIER             {$$=strdup($1);}

PACKAGE_DECLARATION : "package" PACKAGE '{' {startpackage($2);free($2);$2=0;} MAYBECODE '}' {endpackage()}
PACKAGE_DECLARATION : "package" '{' {startpackage("")} MAYBECODE '}' {endpackage()}

IMPORT : "import" QNAME {
       classinfo_t*c = $2;
       if(!c) 
            syntaxerror("Couldn't import class\n");
       state_has_imports();
       dict_put(state->imports, c->name, c);
       $$=0;
}
IMPORT : "import" PACKAGE '.' '*' {
       NEW(import_t,i);
       i->package = $2;
       state_has_imports();
       list_append(state->wildcard_imports, i);
       $$=0;
}

/* ------------ classes and interfaces (header) -------------- */

MAYBE_MODIFIERS : {$$=0;}
MAYBE_MODIFIERS : MODIFIER_LIST {$$=$1}
MODIFIER_LIST : MODIFIER               {$$=$1;}
MODIFIER_LIST : MODIFIER_LIST MODIFIER {$$=$1|$2;}

MODIFIER : KW_PUBLIC {$$=FLAG_PUBLIC;}
         | KW_PRIVATE {$$=FLAG_PRIVATE;}
         | KW_PROTECTED {$$=FLAG_PROTECTED;}
         | KW_STATIC {$$=FLAG_STATIC;}
         | KW_DYNAMIC {$$=FLAG_DYNAMIC;}
         | KW_FINAL {$$=FLAG_FINAL;}
         | KW_OVERRIDE {$$=FLAG_OVERRIDE;}
         | KW_NATIVE {$$=FLAG_NATIVE;}
         | KW_INTERNAL {$$=FLAG_INTERNAL;}

EXTENDS : {$$=registry_getobjectclass();}
EXTENDS : KW_EXTENDS QNAME {$$=$2;}

EXTENDS_LIST : {$$=list_new();}
EXTENDS_LIST : KW_EXTENDS QNAME_LIST {$$=$2;}

IMPLEMENTS_LIST : {$$=list_new();}
IMPLEMENTS_LIST : KW_IMPLEMENTS QNAME_LIST {$$=$2;}

CLASS_DECLARATION : MAYBE_MODIFIERS "class" T_IDENTIFIER 
                              EXTENDS IMPLEMENTS_LIST 
                              '{' {startclass($1,$3,$4,$5, 0);} 
                              MAYBE_DECLARATION_LIST 
                              '}' {endclass();}

INTERFACE_DECLARATION : MAYBE_MODIFIERS "interface" T_IDENTIFIER 
                              EXTENDS_LIST 
                              '{' {startclass($1,$3,0,$4,1);}
                              MAYBE_IDECLARATION_LIST 
                              '}' {endclass();}

/* ------------ classes and interfaces (body) -------------- */

MAYBE_DECLARATION_LIST : 
MAYBE_DECLARATION_LIST : DECLARATION_LIST
DECLARATION_LIST : DECLARATION
DECLARATION_LIST : DECLARATION_LIST DECLARATION
DECLARATION : ';'
DECLARATION : SLOT_DECLARATION
DECLARATION : FUNCTION_DECLARATION

MAYBE_IDECLARATION_LIST : 
MAYBE_IDECLARATION_LIST : IDECLARATION_LIST
IDECLARATION_LIST : IDECLARATION
IDECLARATION_LIST : IDECLARATION_LIST IDECLARATION
IDECLARATION : ';'
IDECLARATION : "var" T_IDENTIFIER {
    syntaxerror("variable declarations not allowed in interfaces");
}
IDECLARATION : MAYBE_MODIFIERS "function" GETSET T_IDENTIFIER '(' MAYBE_PARAM_LIST ')' MAYBETYPE {
    $1 |= FLAG_PUBLIC;
    if($1&(FLAG_PRIVATE|FLAG_INTERNAL|FLAG_PROTECTED)) {
        syntaxerror("invalid method modifiers: interface methods always need to be public");
    }
    startfunction(0,$1,$3,$4,&$6,$8);
    endfunction(0,$1,$3,$4,&$6,$8, 0);
}

/* ------------ classes and interfaces (body, slots ) ------- */

VARCONST: "var" | "const"

SLOT_DECLARATION: MAYBE_MODIFIERS VARCONST T_IDENTIFIER MAYBETYPE MAYBEEXPRESSION {
    int flags = $1;
    memberinfo_t* info = memberinfo_register(state->cls->info, $3, MEMBER_SLOT);
    info->type = $4;
    info->flags = flags;
    trait_t*t=0;

    namespace_t mname_ns = {flags2access(flags), ""};
    multiname_t mname = {QNAME, &mname_ns, 0, $3};

    if(!(flags&FLAG_STATIC)) {
        if($4) {
            MULTINAME(m, $4);
            t=abc_class_slot(state->cls->abc, &mname, &m);
        } else {
            t=abc_class_slot(state->cls->abc, &mname, 0);
        }
        info->slot = t->slot_id;
    } else {
        if($4) {
            MULTINAME(m, $4);
            t=abc_class_staticslot(state->cls->abc, &mname, &m);
        } else {
            t=abc_class_staticslot(state->cls->abc, &mname, 0);
        }
        info->slot = t->slot_id;
    }
    if($5.c && !is_pushundefined($5.c)) {
        code_t*c = 0;
        c = abc_getlocal_0(c);
        c = code_append(c, $5.c);
        c = converttype(c, $5.t, $4);
        c = abc_setslot(c, t->slot_id);
        if(!(flags&FLAG_STATIC))
            state->cls->init = code_append(state->cls->init, c);
        else
            state->cls->static_init = code_append(state->cls->static_init, c);
    }
    if($2==KW_CONST) {
        t->kind= TRAIT_CONST;
    }
}

/* ------------ constants -------------------------------------- */

MAYBESTATICCONSTANT: {$$=0;}
MAYBESTATICCONSTANT: '=' STATICCONSTANT {$$=$2;}

STATICCONSTANT : T_BYTE {$$ = constant_new_int($1);}
STATICCONSTANT : T_INT {$$ = constant_new_int($1);}
STATICCONSTANT : T_UINT {$$ = constant_new_uint($1);}
STATICCONSTANT : T_FLOAT {$$ = constant_new_float($1);}
STATICCONSTANT : T_STRING {$$ = constant_new_string2($1.str,$1.len);}
//STATICCONSTANT : T_NAMESPACE {$$ = constant_new_namespace($1);}
STATICCONSTANT : "true" {$$ = constant_new_true($1);}
STATICCONSTANT : "false" {$$ = constant_new_false($1);}
STATICCONSTANT : "null" {$$ = constant_new_null($1);}

/* ------------ classes and interfaces (body, functions) ------- */

// non-vararg version
MAYBE_PARAM_LIST: {
    memset(&$$,0,sizeof($$));
}
MAYBE_PARAM_LIST: PARAM_LIST {
    $$=$1;
}

// vararg version
MAYBE_PARAM_LIST: "..." PARAM {
    memset(&$$,0,sizeof($$));
    $$.varargs=1;
    list_append($$.list, $2);
}
MAYBE_PARAM_LIST: PARAM_LIST ',' "..." PARAM {
    $$ =$1;
    $$.varargs=1;
    list_append($$.list, $4);
}

// non empty
PARAM_LIST: PARAM_LIST ',' PARAM {
    $$ = $1;
    list_append($$.list, $3);
}
PARAM_LIST: PARAM {
    memset(&$$,0,sizeof($$));
    list_append($$.list, $1);
}

PARAM:  T_IDENTIFIER ':' TYPE MAYBESTATICCONSTANT {
     $$ = malloc(sizeof(param_t));
     $$->name=$1;
     $$->type = $3;
     $$->value = $4;
}
PARAM:  T_IDENTIFIER MAYBESTATICCONSTANT {
     $$ = malloc(sizeof(param_t));
     $$->name=$1;
     $$->type = TYPE_ANY;
     $$->value = $2;
}
GETSET : "get" {$$=$1;}
       | "set" {$$=$1;}
       |       {$$=0;}

FUNCTION_DECLARATION: MAYBE_MODIFIERS "function" GETSET T_IDENTIFIER '(' MAYBE_PARAM_LIST ')' 
                      MAYBETYPE '{' {startfunction(0,$1,$3,$4,&$6,$8)} MAYBECODE '}' 
{
    code_t*c = 0;
    if(state->method->late_binding) {
        c = abc_getlocal_0(c);
        c = abc_pushscope(c);
    }
    if(state->method->is_constructor && !state->method->has_super) {
        // call default constructor
        c = abc_getlocal_0(c);
        c = abc_constructsuper(c, 0);
    }
    c = wrap_function(c, state->method->initcode, $11);
    endfunction(0,$1,$3,$4,&$6,$8,c);
}

/* ------------- package + class ids --------------- */

CLASS: T_IDENTIFIER {

    /* try current package */
    $$ = find_class($1);
    if(!$$) syntaxerror("Could not find class %s\n", $1);
}

PACKAGEANDCLASS : PACKAGE '.' T_IDENTIFIER {
    $$ = registry_findclass($1, $3);
    if(!$$) syntaxerror("Couldn't find class %s.%s\n", $1, $3);
    free($1);$1=0;
}

QNAME: PACKAGEANDCLASS
     | CLASS

QNAME_LIST : QNAME {$$=list_new();list_append($$, $1);}
QNAME_LIST : QNAME_LIST ',' QNAME {$$=$1;list_append($$,$3);}

TYPE : QNAME      {$$=$1;}
     | '*'        {$$=registry_getanytype();}
     | "void"     {$$=registry_getanytype();}
    /*
     |  "String"  {$$=registry_getstringclass();}
     |  "int"     {$$=registry_getintclass();}
     |  "uint"    {$$=registry_getuintclass();}
     |  "Boolean" {$$=registry_getbooleanclass();}
     |  "Number"  {$$=registry_getnumberclass();}
    */

MAYBETYPE: ':' TYPE {$$=$2;}
MAYBETYPE:          {$$=0;}

/* ----------function calls, delete, constructor calls ------ */

MAYBE_PARAM_VALUES :  %prec prec_none {$$.cc=0;$$.len=0;}
MAYBE_PARAM_VALUES : '(' MAYBE_EXPRESSION_LIST ')' {$$=$2}

MAYBE_EXPRESSION_LIST : {$$.cc=0;$$.len=0;}
MAYBE_EXPRESSION_LIST : EXPRESSION_LIST
EXPRESSION_LIST : NONCOMMAEXPRESSION             {$$.len=1;
                                                  $$.cc = $1.c;
                                                 }
EXPRESSION_LIST : EXPRESSION_LIST ',' NONCOMMAEXPRESSION {
                                                  $$.len= $1.len+1;
                                                  $$.cc = code_append($1.cc, $3.c);
                                                  }

NEW : "new" CLASS MAYBE_PARAM_VALUES {
    MULTINAME(m, $2);
    $$.c = code_new();

    if($2->slot) {
        $$.c = abc_getglobalscope($$.c);
        $$.c = abc_getslot($$.c, $2->slot);
    } else {
        $$.c = abc_findpropstrict2($$.c, &m);
    }

    $$.c = code_append($$.c, $3.cc);

    if($2->slot)
        $$.c = abc_construct($$.c, $3.len);
    else
        $$.c = abc_constructprop2($$.c, &m, $3.len);
    $$.t = $2;
}

/* TODO: use abc_call (for calling local variables),
         abc_callstatic (for calling own methods) 
         call (for closures)
*/
FUNCTIONCALL : E '(' MAYBE_EXPRESSION_LIST ')' {
    
    $$.c = $1.c;
    if($$.c->opcode == OPCODE_COERCE_A) {
        $$.c = code_cutlast($$.c);
    }
    code_t*paramcode = $3.cc;

    $$.t = TYPE_ANY;
    if($$.c->opcode == OPCODE_GETPROPERTY) {
        multiname_t*name = $$.c->data[0];$$.c->data[0]=0;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_callproperty2($$.c, name, $3.len);
        multiname_destroy(name);
    } else if($$.c->opcode == OPCODE_GETSLOT) {
        int slot = (int)(ptroff_t)$$.c->data[0];
        trait_t*t = abc_class_find_slotid(state->cls->abc,slot);//FIXME
        if(t->kind!=TRAIT_METHOD) {
            //ok: flash allows to assign closures to members.
        }
        multiname_t*name = t->name;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        //$$.c = abc_callmethod($$.c, t->method, len); //#1051 illegal early access binding
        $$.c = abc_callproperty2($$.c, name, $3.len);
    } else if($$.c->opcode == OPCODE_GETSUPER) {
        multiname_t*name = $$.c->data[0];$$.c->data[0]=0;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_callsuper2($$.c, name, $3.len);
        multiname_destroy(name);
    } else {
        $$.c = abc_getlocal_0($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_call($$.c, $3.len);
    }
   
    memberinfo_t*f = 0;
   
    if(TYPE_IS_FUNCTION($1.t) && $1.t->function) {
        $$.t = $1.t->function->return_type;
    } else {
        $$.c = abc_coerce_a($$.c);
        $$.t = TYPE_ANY;
    }

}
FUNCTIONCALL : "super" '(' MAYBE_EXPRESSION_LIST ')' {
    if(!state->cls) syntaxerror("super() not allowed outside of a class");
    if(!state->method) syntaxerror("super() not allowed outside of a function");
    if(!state->method->is_constructor) syntaxerror("super() not allowed outside of a constructor");

    $$.c = code_new();
    $$.c = abc_getlocal_0($$.c);

    $$.c = code_append($$.c, $3.cc);
    /*
    this is dependent on the control path, check this somewhere else
    if(state->method->has_super)
        syntaxerror("constructor may call super() only once");
    */
    state->method->has_super = 1;
    $$.c = abc_constructsuper($$.c, $3.len);
    $$.c = abc_pushundefined($$.c);
    $$.t = TYPE_ANY;
}

DELETE: "delete" E {
    $$.c = $2.c;
    if($$.c->opcode == OPCODE_COERCE_A) {
        $$.c = code_cutlast($$.c);
    }
    multiname_t*name = 0;
    if($$.c->opcode == OPCODE_GETPROPERTY) {
        $$.c->opcode = OPCODE_DELETEPROPERTY;
    } else if($$.c->opcode == OPCODE_GETSLOT) {
        int slot = (int)(ptroff_t)$$.c->data[0];
        multiname_t*name = abc_class_find_slotid(state->cls->abc,slot)->name;
        $$.c = code_cutlast($$.c);
        $$.c = abc_deleteproperty2($$.c, name);
    } else {
        $$.c = abc_getlocal_0($$.c);
        MULTINAME_LATE(m, $2.t?$2.t->access:ACCESS_PACKAGE, "");
        $$.c = abc_deleteproperty2($$.c, &m);
    }
    $$.t = TYPE_BOOLEAN;
}

RETURN: "return" %prec prec_none {
    $$ = abc_returnvoid(0);
}
RETURN: "return" EXPRESSION {
    $$ = $2.c;
    $$ = abc_returnvalue($$);
}

// ----------------------- expression types -------------------------------------

NONCOMMAEXPRESSION : E        %prec below_minus {$$=$1;}
EXPRESSION : E                %prec below_minus {$$ = $1;}
EXPRESSION : EXPRESSION ',' E %prec below_minus {
    $$.c = $1.c;
    $$.c = cut_last_push($$.c);
    $$.c = code_append($$.c,$3.c);
    $$.t = $3.t;
}
VOIDEXPRESSION : EXPRESSION %prec below_minus {
    $$=cut_last_push($1.c);
}

// ----------------------- expression evaluation -------------------------------------

E : CONSTANT
E : VAR_READ %prec T_IDENTIFIER {$$ = $1;}
E : NEW                         {$$ = $1;}
E : DELETE                      {$$ = $1;}
E : T_REGEXP                    {$$.c = abc_pushundefined(0); /* FIXME */
                                 $$.t = TYPE_ANY;
                                }

CONSTANT : T_BYTE {$$.c = abc_pushbyte(0, $1);
                   //MULTINAME(m, registry_getintclass());
                   //$$.c = abc_coerce2($$.c, &m); // FIXME
                   $$.t = TYPE_INT;
                  }
CONSTANT : T_SHORT {$$.c = abc_pushshort(0, $1);
                    $$.t = TYPE_INT;
                   }
CONSTANT : T_INT {$$.c = abc_pushint(0, $1);
                  $$.t = TYPE_INT;
                 }
CONSTANT : T_UINT {$$.c = abc_pushuint(0, $1);
                   $$.t = TYPE_UINT;
                  }
CONSTANT : T_FLOAT {$$.c = abc_pushdouble(0, $1);
                    $$.t = TYPE_FLOAT;
                   }
CONSTANT : T_STRING {$$.c = abc_pushstring2(0, &$1);
                     $$.t = TYPE_STRING;
                    }
CONSTANT : "undefined" {$$.c = abc_pushundefined(0);
                    $$.t = TYPE_ANY;
                   }
CONSTANT : "true" {$$.c = abc_pushtrue(0);
                    $$.t = TYPE_BOOLEAN;
                   }
CONSTANT : "false" {$$.c = abc_pushfalse(0);
                     $$.t = TYPE_BOOLEAN;
                    }
CONSTANT : "null" {$$.c = abc_pushnull(0);
                    $$.t = TYPE_NULL;
                   }

E : FUNCTIONCALL
E : E '<' E {$$.c = code_append($1.c,$3.c);$$.c = abc_greaterequals($$.c);$$.c=abc_not($$.c);
             $$.t = TYPE_BOOLEAN;
            }
E : E '>' E {$$.c = code_append($1.c,$3.c);$$.c = abc_greaterthan($$.c);
             $$.t = TYPE_BOOLEAN;
            }
E : E "<=" E {$$.c = code_append($1.c,$3.c);$$.c = abc_greaterthan($$.c);$$.c=abc_not($$.c);
              $$.t = TYPE_BOOLEAN;
             }
E : E ">=" E {$$.c = code_append($1.c,$3.c);$$.c = abc_greaterequals($$.c);
              $$.t = TYPE_BOOLEAN;
             }
E : E "==" E {$$.c = code_append($1.c,$3.c);$$.c = abc_equals($$.c);
              $$.t = TYPE_BOOLEAN;
             }
E : E "===" E {$$.c = code_append($1.c,$3.c);$$.c = abc_strictequals($$.c);
              $$.t = TYPE_BOOLEAN;
              }
E : E "!==" E {$$.c = code_append($1.c,$3.c);$$.c = abc_strictequals($$.c);$$.c = abc_not($$.c);
              $$.t = TYPE_BOOLEAN;
             }
E : E "!=" E {$$.c = code_append($1.c,$3.c);$$.c = abc_equals($$.c);$$.c = abc_not($$.c);
              $$.t = TYPE_BOOLEAN;
             }

E : E "||" E {$$.t = join_types($1.t, $3.t, 'O');
              $$.c = $1.c;
              $$.c = converttype($$.c, $1.t, $$.t);
              $$.c = abc_dup($$.c);
              code_t*jmp = $$.c = abc_iftrue($$.c, 0);
              $$.c = cut_last_push($$.c);
              $$.c = code_append($$.c,$3.c);
              $$.c = converttype($$.c, $3.t, $$.t);
              code_t*label = $$.c = abc_label($$.c);
              jmp->branch = label;
             }
E : E "&&" E {
              $$.t = join_types($1.t, $3.t, 'A');
              /*printf("%08x:\n",$1.t);
              code_dump($1.c, 0, 0, "", stdout);
              printf("%08x:\n",$3.t);
              code_dump($3.c, 0, 0, "", stdout);
              printf("joining %08x and %08x to %08x\n", $1.t, $3.t, $$.t);*/
              $$.c = $1.c;
              $$.c = converttype($$.c, $1.t, $$.t);
              $$.c = abc_dup($$.c);
              code_t*jmp = $$.c = abc_iffalse($$.c, 0);
              $$.c = cut_last_push($$.c);
              $$.c = code_append($$.c,$3.c);
              $$.c = converttype($$.c, $3.t, $$.t);
              code_t*label = $$.c = abc_label($$.c);
              jmp->branch = label;              
             }

E : '!' E    {$$.c=$2.c;
              $$.c = abc_not($$.c);
              $$.t = TYPE_BOOLEAN;
             }

E : '~' E    {$$.c=$2.c;
              $$.c = abc_bitnot($$.c);
              $$.t = TYPE_INT;
             }

E : E '&' E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_bitand($$.c);
             $$.t = TYPE_INT;
            }

E : E '^' E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_bitxor($$.c);
             $$.t = TYPE_INT;
            }

E : E '|' E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_bitor($$.c);
             $$.t = TYPE_INT;
            }

E : E '-' E {$$.c = code_append($1.c,$3.c);
             if(BOTH_INT($1,$3)) {
                $$.c = abc_subtract_i($$.c);
                $$.t = TYPE_INT;
             } else {
                $$.c = abc_subtract($$.c);
                $$.t = TYPE_NUMBER;
             }
            }
E : E ">>" E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_rshift($$.c);
             $$.t = TYPE_INT;
            }
E : E ">>>" E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_urshift($$.c);
             $$.t = TYPE_INT;
            }
E : E "<<" E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_lshift($$.c);
             $$.t = TYPE_INT;
            }

E : E '/' E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_divide($$.c);
             $$.t = TYPE_NUMBER;
            }
E : E '+' E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_add($$.c);
             $$.t = TYPE_NUMBER;
            }
E : E '%' E {$$.c = code_append($1.c,$3.c);
             $$.c = abc_modulo($$.c);
             $$.t = TYPE_NUMBER;
            }
E : E '*' E {$$.c = code_append($1.c,$3.c);
             if(BOTH_INT($1,$3)) {
                $$.c = abc_multiply_i($$.c);
                $$.t = TYPE_INT;
             } else {
                $$.c = abc_multiply($$.c);
                $$.t = TYPE_NUMBER;
             }
            }

E : E "in" E {$$.c = code_append($1.c,$3.c);
              $$.c = abc_in($$.c);
              $$.t = TYPE_BOOLEAN;
             }

E : E "as" E {char use_astype=0; // flash player's astype works differently than astypelate
              if(use_astype && TYPE_IS_CLASS($3.t)) {
                MULTINAME(m,$3.t->cls);
                $$.c = abc_astype2($1.c, &m);
                $$.t = $3.t->cls;
              } else {
                $$.c = code_append($1.c, $3.c);
                $$.c = abc_astypelate($$.c);
                $$.t = TYPE_ANY;
              }
             }

E : E "instanceof" E 
             {$$.c = code_append($1.c, $3.c);
              $$.c = abc_instanceof($$.c);
              $$.t = TYPE_BOOLEAN;
             }

E : E "is" E {$$.c = code_append($1.c, $3.c);
              $$.c = abc_istypelate($$.c);
              $$.t = TYPE_BOOLEAN;
             }

E : "typeof" '(' E ')' {
              $$.c = $3.c;
              $$.c = abc_typeof($$.c);
              $$.t = TYPE_STRING;
             }

E : "void" E {
              $$.c = cut_last_push($2.c);
              $$.c = abc_pushundefined($$.c);
              $$.t = TYPE_ANY;
             }

E : "void" { $$.c = abc_pushundefined(0);
             $$.t = TYPE_ANY;
           }

E : '(' EXPRESSION ')' {$$=$2;} //allow commas in here, too

E : '-' E {
  $$=$2;
  if(IS_INT($2)) {
   $$.c=abc_negate_i($$.c);
   $$.t = TYPE_INT;
  } else {
   $$.c=abc_negate($$.c);
   $$.t = TYPE_NUMBER;
  }
}

E : E '[' E ']' {
  $$.c = $1.c;
  $$.c = code_append($$.c, $3.c);
 
  MULTINAME_LATE(m, $1.t?$1.t->access:ACCESS_PACKAGE, "");
  $$.c = abc_getproperty2($$.c, &m);
  $$.t = 0; // array elements have unknown type
}

E : '[' MAYBE_EXPRESSION_LIST ']' {
    $$.c = code_new();
    $$.c = code_append($$.c, $2.cc);
    $$.c = abc_newarray($$.c, $2.len);
    $$.t = registry_getarrayclass();
}

MAYBE_EXPRPAIR_LIST : {$$.cc=0;$$.len=0;}
MAYBE_EXPRPAIR_LIST : EXPRPAIR_LIST {$$=$1};

EXPRPAIR_LIST : NONCOMMAEXPRESSION ':' NONCOMMAEXPRESSION {
    $$.cc = 0;
    $$.cc = code_append($$.cc, $1.c);
    $$.cc = code_append($$.cc, $3.c);
    $$.len = 2;
}
EXPRPAIR_LIST : EXPRPAIR_LIST ',' NONCOMMAEXPRESSION ':' NONCOMMAEXPRESSION {
    $$.cc = $1.cc;
    $$.len = $1.len+2;
    $$.cc = code_append($$.cc, $3.c);
    $$.cc = code_append($$.cc, $5.c);
}
//MAYBECOMMA: ','
//MAYBECOMMA:

E : '{' MAYBE_EXPRPAIR_LIST '}' {
    $$.c = code_new();
    $$.c = code_append($$.c, $2.cc);
    $$.c = abc_newobject($$.c, $2.len/2);
    $$.t = registry_getobjectclass();
}

E : E "*=" E { 
               code_t*c = $3.c;
               if(BOTH_INT($1,$3)) {
                c=abc_multiply_i(c);
               } else {
                c=abc_multiply(c);
               }
               c=converttype(c, join_types($1.t, $3.t, '*'), $1.t);
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }

E : E "%=" E { 
               code_t*c = abc_modulo($3.c);
               c=converttype(c, join_types($1.t, $3.t, '%'), $1.t);
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }
E : E "<<=" E { 
               code_t*c = abc_lshift($3.c);
               c=converttype(c, join_types($1.t, $3.t, '<'), $1.t);
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }
E : E ">>=" E { 
               code_t*c = abc_rshift($3.c);
               c=converttype(c, join_types($1.t, $3.t, '>'), $1.t);
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }
E : E ">>>=" E { 
               code_t*c = abc_urshift($3.c);
               c=converttype(c, join_types($1.t, $3.t, 'U'), $1.t);
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }
E : E "/=" E { 
               code_t*c = abc_divide($3.c);
               c=converttype(c, join_types($1.t, $3.t, '/'), $1.t);
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }
E : E "+=" E { 
               code_t*c = $3.c;
               if(TYPE_IS_INT($3.t) || TYPE_IS_UINT($3.t)) {
                c=abc_add_i(c);
               } else {
                c=abc_add(c);
               }
               c=converttype(c, join_types($1.t, $3.t, '+'), $1.t);
               
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
              }
E : E "-=" E { code_t*c = $3.c; 
               if(TYPE_IS_INT($3.t) || TYPE_IS_UINT($3.t)) {
                c=abc_subtract_i(c);
               } else {
                c=abc_subtract(c);
               }
               c=converttype(c, join_types($1.t, $3.t, '-'), $1.t);
               
               $$.c = toreadwrite($1.c, c, 0, 0);
               $$.t = $1.t;
             }
E : E '=' E { code_t*c = 0;
              c = code_append(c, $3.c);
              c = converttype(c, $3.t, $1.t);
              $$.c = toreadwrite($1.c, c, 1, 0);
              $$.t = $1.t;
            }

E : E '?' E ':' E %prec below_assignment { 
              $$.c = $1.c;
              code_t*j1 = $$.c = abc_iffalse($$.c, 0);
              $$.c = code_append($$.c, $3.c);
              code_t*j2 = $$.c = abc_jump($$.c, 0);
              $$.c = j1->branch = abc_label($$.c);
              $$.c = code_append($$.c, $5.c);
              $$.c = j2->branch = abc_label($$.c);
              $$.t = join_types($3.t,$5.t,'?');
            }

// TODO: use inclocal where appropriate
E : E "++" { code_t*c = 0;
             classinfo_t*type = $1.t;
             if(TYPE_IS_INT(type) || TYPE_IS_UINT(type)) {
                 c=abc_increment_i(c);
                 type = TYPE_INT;
             } else {
                 c=abc_increment(c);
                 type = TYPE_NUMBER;
             }
             c=converttype(c, type, $1.t);
             $$.c = toreadwrite($1.c, c, 0, 1);
             $$.t = $1.t;
           }
E : E "--" { code_t*c = 0;
             classinfo_t*type = $1.t;
             if(TYPE_IS_INT(type) || TYPE_IS_UINT(type)) {
                 c=abc_decrement_i(c);
                 type = TYPE_INT;
             } else {
                 c=abc_decrement(c);
                 type = TYPE_NUMBER;
             }
             c=converttype(c, type, $1.t);
             $$.c = toreadwrite($1.c, c, 0, 1);
             $$.t = $1.t;
            }

E : "++" %prec plusplus_prefix E { code_t*c = 0;
             classinfo_t*type = $2.t;
             if(TYPE_IS_INT(type) || TYPE_IS_UINT(type)) {
                 c=abc_increment_i(c);
                 type = TYPE_INT;
             } else {
                 c=abc_increment(c);
                 type = TYPE_NUMBER;
             }
             c=converttype(c, type, $2.t);
             $$.c = toreadwrite($2.c, c, 0, 0);
             $$.t = $2.t;
           }

E : "--" %prec minusminus_prefix E { code_t*c = 0;
             classinfo_t*type = $2.t;
             if(TYPE_IS_INT(type) || TYPE_IS_UINT(type)) {
                 c=abc_decrement_i(c);
                 type = TYPE_INT;
             } else {
                 c=abc_decrement(c);
                 type = TYPE_NUMBER;
             }
             c=converttype(c, type, $2.t);
             $$.c = toreadwrite($2.c, c, 0, 0);
             $$.t = $2.t;
           }

E : "super" '.' T_IDENTIFIER 
           { if(!state->cls->info)
                  syntaxerror("super keyword not allowed outside a class");
              classinfo_t*t = state->cls->info->superclass;
              if(!t) t = TYPE_OBJECT;

              memberinfo_t*f = registry_findmember(t, $3, 1);
              namespace_t ns = {flags2access(f->flags), ""};
              MEMBER_MULTINAME(m, f, $3);
              $$.c = 0;
              $$.c = abc_getlocal_0($$.c);
              $$.c = abc_getsuper2($$.c, &m);
              $$.t = memberinfo_gettype(f);
           }

E : E '.' T_IDENTIFIER
            {$$.c = $1.c;
             classinfo_t*t = $1.t;
             char is_static = 0;
             if(TYPE_IS_CLASS(t) && t->cls) {
                 t = t->cls;
                 is_static = 1;
             }
             if(t) {
                 memberinfo_t*f = registry_findmember(t, $3, 1);
                 char noslot = 0;
                 if(f && !is_static != !(f->flags&FLAG_STATIC))
                    noslot=1;
                 if(f && f->slot && !noslot) {
                     $$.c = abc_getslot($$.c, f->slot);
                 } else {
                     MEMBER_MULTINAME(m, f, $3);
                     $$.c = abc_getproperty2($$.c, &m);
                 }
                 /* determine type */
                 $$.t = memberinfo_gettype(f);
                 if(!$$.t)
                    $$.c = abc_coerce_a($$.c);
             } else {
                 /* when resolving a property on an unknown type, we do know the
                    name of the property (and don't seem to need the package), but
                    we need to make avm2 try out all access modes */
                 multiname_t m = {MULTINAME, 0, &nopackage_namespace_set, $3};
                 $$.c = abc_getproperty2($$.c, &m);
                 $$.c = abc_coerce_a($$.c);
                 $$.t = registry_getanytype();
             }
            }

VAR_READ : T_IDENTIFIER {
    $$.t = 0;
    $$.c = 0;
    classinfo_t*a = 0;
    memberinfo_t*f = 0;

    variable_t*v;
    /* look at variables */
    if((v = find_variable($1))) {
        // $1 is a local variable
        $$.c = abc_getlocal($$.c, v->index);
        $$.t = v->type;

    /* look at current class' members */
    } else if(state->cls && (f = registry_findmember(state->cls->info, $1, 1))) {
        // $1 is a function in this class
        int var_is_static = (f->flags&FLAG_STATIC);
        int i_am_static = ((state->method && state->method->info)?(state->method->info->flags&FLAG_STATIC):FLAG_STATIC);
        if(var_is_static != i_am_static) {
            /* there doesn't seem to be any "static" way to access
               static properties of a class */
            state->method->late_binding = 1;
            $$.t = f->type;
            namespace_t ns = {flags2access(f->flags), ""};
            multiname_t m = {QNAME, &ns, 0, $1};
            $$.c = abc_findpropstrict2($$.c, &m);
            $$.c = abc_getproperty2($$.c, &m);
        } else {
            if(f->slot>0) {
                $$.c = abc_getlocal_0($$.c);
                $$.c = abc_getslot($$.c, f->slot);
            } else {
                namespace_t ns = {flags2access(f->flags), ""};
                multiname_t m = {QNAME, &ns, 0, $1};
                $$.c = abc_getlocal_0($$.c);
                $$.c = abc_getproperty2($$.c, &m);
            }
        }
        if(f->kind == MEMBER_METHOD) {
            $$.t = TYPE_FUNCTION(f);
        } else {
            $$.t = f->type;
        }
    
    /* look at actual classes, in the current package and imported */
    } else if((a = find_class($1))) {
        if(a->flags & FLAG_METHOD) {
            MULTINAME(m, a);
            $$.c = abc_findpropstrict2($$.c, &m);
            $$.c = abc_getproperty2($$.c, &m);
            $$.t = TYPE_FUNCTION(a->function);
        } else {
            if(a->slot) {
                $$.c = abc_getglobalscope($$.c);
                $$.c = abc_getslot($$.c, a->slot);
            } else {
                MULTINAME(m, a);
                $$.c = abc_getlex2($$.c, &m);
            }
            $$.t = TYPE_CLASS(a);
        }

    /* unknown object, let the avm2 resolve it */
    } else {
        if(strcmp($1,"trace"))
            warning("Couldn't resolve '%s', doing late binding", $1);
        state->method->late_binding = 1;
                
        multiname_t m = {MULTINAME, 0, &nopackage_namespace_set, $1};

        $$.t = 0;
        $$.c = abc_findpropstrict2($$.c, &m);
        $$.c = abc_getproperty2($$.c, &m);
    }
}

//TODO: 
//VARIABLE : VARIABLE ".." T_IDENTIFIER // descendants
//VARIABLE : VARIABLE "::" VARIABLE // namespace declaration
//VARIABLE : VARIABLE "::" '[' EXPRESSION ']' // qualified expression

// ----------------- namespaces -------------------------------------------------

NAMESPACE_DECLARATION : MAYBE_MODIFIERS "namespace" T_IDENTIFIER {$$=$2;}
NAMESPACE_DECLARATION : MAYBE_MODIFIERS "namespace" T_IDENTIFIER '=' T_IDENTIFIER {$$=$2;}
NAMESPACE_DECLARATION : MAYBE_MODIFIERS "namespace" T_IDENTIFIER '=' T_STRING {$$=$2;}

USE_NAMESPACE : "use" "namespace" T_IDENTIFIER

