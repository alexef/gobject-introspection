/* GObject introspection: C parser
 *
 * Copyright (c) 1997 Sandro Sigala  <ssigala@globalnet.it>
 * Copyright (c) 2007-2008 Jürg Billeter  <j@bitron.ch>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <glib.h>
#include "sourcescanner.h"
#include "scannerparser.h"

extern FILE *yyin;
extern int lineno;
extern char *yytext;

extern int yylex (GISourceScanner *scanner);
static void yyerror (GISourceScanner *scanner, const char *str);
 
static int last_enum_value = -1;
static GHashTable *const_table = NULL;
%}

%error-verbose
%union {
  char *str;
  GList *list;
  GISourceSymbol *symbol;
  GISourceType *ctype;
  StorageClassSpecifier storage_class_specifier;
  TypeQualifier type_qualifier;
  FunctionSpecifier function_specifier;
  UnaryOperator unary_operator;
}

%parse-param { GISourceScanner* scanner }
%lex-param { GISourceScanner* scanner }

%token <str> IDENTIFIER "identifier"
%token <str> TYPEDEF_NAME "typedef-name"

%token INTEGER FLOATING CHARACTER STRING

%token ELLIPSIS ADDEQ SUBEQ MULEQ DIVEQ MODEQ XOREQ ANDEQ OREQ SL SR
%token SLEQ SREQ EQ NOTEQ LTEQ GTEQ ANDAND OROR PLUSPLUS MINUSMINUS ARROW

%token AUTO BOOL BREAK CASE CHAR CONST CONTINUE DEFAULT DO DOUBLE ELSE ENUM
%token EXTERN FLOAT FOR GOTO IF INLINE INT LONG REGISTER RESTRICT RETURN SHORT
%token SIGNED SIZEOF STATIC STRUCT SWITCH TYPEDEF UNION UNSIGNED VOID VOLATILE
%token WHILE

%token FUNCTION_MACRO OBJECT_MACRO

%start translation_unit

%type <ctype> declaration_specifiers
%type <ctype> enum_specifier
%type <ctype> pointer
%type <ctype> specifier_qualifier_list
%type <ctype> type_name
%type <ctype> struct_or_union
%type <ctype> struct_or_union_specifier
%type <ctype> type_specifier
%type <str> identifier
%type <str> typedef_name
%type <str> identifier_or_typedef_name
%type <symbol> abstract_declarator
%type <symbol> init_declarator
%type <symbol> declarator
%type <symbol> enumerator
%type <symbol> direct_abstract_declarator
%type <symbol> direct_declarator
%type <symbol> parameter_declaration
%type <symbol> struct_declarator
%type <list> enumerator_list
%type <list> identifier_list
%type <list> init_declarator_list
%type <list> parameter_type_list
%type <list> parameter_list
%type <list> struct_declaration
%type <list> struct_declaration_list
%type <list> struct_declarator_list
%type <storage_class_specifier> storage_class_specifier
%type <type_qualifier> type_qualifier
%type <type_qualifier> type_qualifier_list
%type <function_specifier> function_specifier
%type <symbol> expression
%type <symbol> constant_expression
%type <symbol> conditional_expression
%type <symbol> logical_and_expression
%type <symbol> logical_or_expression
%type <symbol> inclusive_or_expression
%type <symbol> exclusive_or_expression
%type <symbol> multiplicative_expression
%type <symbol> additive_expression
%type <symbol> shift_expression
%type <symbol> relational_expression
%type <symbol> equality_expression
%type <symbol> and_expression
%type <symbol> cast_expression
%type <symbol> assignment_expression
%type <symbol> unary_expression
%type <symbol> postfix_expression
%type <symbol> primary_expression
%type <unary_operator> unary_operator
%type <str> function_macro
%type <str> object_macro
%type <symbol> strings

%%

/* A.2.1 Expressions. */

primary_expression
	: identifier
	  {
		$$ = g_hash_table_lookup (const_table, $1);
		if ($$ == NULL) {
			$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		} else {
			$$ = gi_source_symbol_ref ($$);
		}
	  }
	| INTEGER
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		if (g_str_has_prefix (yytext, "0x") && strlen (yytext) > 2) {
			$$->const_int = strtol (yytext + 2, NULL, 16);
		} else if (g_str_has_prefix (yytext, "0") && strlen (yytext) > 1) {
			$$->const_int = strtol (yytext + 1, NULL, 8);
		} else {
			$$->const_int = atoi (yytext);
		}
	  }
	| CHARACTER
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| FLOATING
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| strings
	| '(' expression ')'
	  {
		$$ = $2;
	  }
	;

/* concatenate adjacent string literal tokens */
strings
	: STRING
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		yytext[strlen (yytext) - 1] = '\0';
		$$->const_string = g_strcompress (yytext + 1);
	  }
	| strings STRING
	  {
		char *strings, *string2;
		$$ = $1;
		yytext[strlen (yytext) - 1] = '\0';
		string2 = g_strcompress (yytext + 1);
		strings = g_strconcat ($$->const_string, string2, NULL);
		g_free ($$->const_string);
		g_free (string2);
		$$->const_string = strings;
	  }
	;

identifier
	: IDENTIFIER
	  {
		$$ = g_strdup (yytext);
	  }
	;

identifier_or_typedef_name
	: identifier
	| typedef_name
	;

postfix_expression
	: primary_expression
	| postfix_expression '[' expression ']'
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| postfix_expression '(' argument_expression_list ')'
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| postfix_expression '(' ')'
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| postfix_expression '.' identifier_or_typedef_name
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| postfix_expression ARROW identifier_or_typedef_name
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| postfix_expression PLUSPLUS
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| postfix_expression MINUSMINUS
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	;

argument_expression_list
	: assignment_expression
	| argument_expression_list ',' assignment_expression
	;

unary_expression
	: postfix_expression
	| PLUSPLUS unary_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| MINUSMINUS unary_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| unary_operator cast_expression
	  {
		switch ($1) {
		case UNARY_PLUS:
			$$ = $2;
			break;
		case UNARY_MINUS:
			$$ = $2;
			$$->const_int = -$2->const_int;
			break;
		case UNARY_BITWISE_COMPLEMENT:
			$$ = $2;
			$$->const_int = ~$2->const_int;
			break;
		case UNARY_LOGICAL_NEGATION:
			$$ = $2;
			$$->const_int = !gi_source_symbol_get_const_boolean ($2);
			break;
		default:
			$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
			break;
		}
	  }
	| SIZEOF unary_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| SIZEOF '(' type_name ')'
	  {
		ctype_free ($3);
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	;

unary_operator
	: '&'
	  {
		$$ = UNARY_ADDRESS_OF;
	  }
	| '*'
	  {
		$$ = UNARY_POINTER_INDIRECTION;
	  }
	| '+'
	  {
		$$ = UNARY_PLUS;
	  }
	| '-'
	  {
		$$ = UNARY_MINUS;
	  }
	| '~'
	  {
		$$ = UNARY_BITWISE_COMPLEMENT;
	  }
	| '!'
	  {
		$$ = UNARY_LOGICAL_NEGATION;
	  }
	;

cast_expression
	: unary_expression
	| '(' type_name ')' cast_expression
	  {
		ctype_free ($2);
		$$ = $4;
	  }
	;

multiplicative_expression
	: cast_expression
	| multiplicative_expression '*' cast_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int * $3->const_int;
	  }
	| multiplicative_expression '/' cast_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		if ($3->const_int != 0) {
			$$->const_int = $1->const_int / $3->const_int;
		}
	  }
	| multiplicative_expression '%' cast_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int % $3->const_int;
	  }
	;

additive_expression
	: multiplicative_expression
	| additive_expression '+' multiplicative_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int + $3->const_int;
	  }
	| additive_expression '-' multiplicative_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int - $3->const_int;
	  }
	;

shift_expression
	: additive_expression
	| shift_expression SL additive_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int << $3->const_int;
	  }
	| shift_expression SR additive_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int >> $3->const_int;
	  }
	;

relational_expression
	: shift_expression
	| relational_expression '<' shift_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int < $3->const_int;
	  }
	| relational_expression '>' shift_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int > $3->const_int;
	  }
	| relational_expression LTEQ shift_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int <= $3->const_int;
	  }
	| relational_expression GTEQ shift_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int >= $3->const_int;
	  }
	;

equality_expression
	: relational_expression
	| equality_expression EQ relational_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int == $3->const_int;
	  }
	| equality_expression NOTEQ relational_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int != $3->const_int;
	  }
	;

and_expression
	: equality_expression
	| and_expression '&' equality_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int & $3->const_int;
	  }
	;

exclusive_or_expression
	: and_expression
	| exclusive_or_expression '^' and_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int ^ $3->const_int;
	  }
	;

inclusive_or_expression
	: exclusive_or_expression
	| inclusive_or_expression '|' exclusive_or_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int = $1->const_int | $3->const_int;
	  }
	;

logical_and_expression
	: inclusive_or_expression
	| logical_and_expression ANDAND inclusive_or_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int =
		  gi_source_symbol_get_const_boolean ($1) &&
		  gi_source_symbol_get_const_boolean ($3);
	  }
	;

logical_or_expression
	: logical_and_expression
	| logical_or_expression OROR logical_and_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_CONST);
		$$->const_int_set = TRUE;
		$$->const_int =
		  gi_source_symbol_get_const_boolean ($1) ||
		  gi_source_symbol_get_const_boolean ($3);
	  }
	;

conditional_expression
	: logical_or_expression
	| logical_or_expression '?' expression ':' conditional_expression
	  {
		$$ = gi_source_symbol_get_const_boolean ($1) ? $3 : $5;
	  }
	;

assignment_expression
	: conditional_expression
	| unary_expression assignment_operator assignment_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	;

assignment_operator
	: '='
	| MULEQ
	| DIVEQ
	| MODEQ
	| ADDEQ
	| SUBEQ
	| SLEQ
	| SREQ
	| ANDEQ
	| XOREQ
	| OREQ
	;

expression
	: assignment_expression
	| expression ',' assignment_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	;

constant_expression
	: conditional_expression
	;

/* A.2.2 Declarations. */

declaration
	: declaration_specifiers init_declarator_list ';'
	  {
		GList *l;
		for (l = $2; l != NULL; l = l->next) {
			GISourceSymbol *sym = l->data;
			gi_source_symbol_merge_type (sym, gi_source_type_copy ($1));
			if ($1->storage_class_specifier & STORAGE_CLASS_TYPEDEF) {
				sym->type = CSYMBOL_TYPE_TYPEDEF;
			} else if (sym->base_type->type == CTYPE_FUNCTION) {
				sym->type = CSYMBOL_TYPE_FUNCTION;
			} else {
				sym->type = CSYMBOL_TYPE_OBJECT;
			}
			gi_source_scanner_add_symbol (scanner, sym);
			gi_source_symbol_unref (sym);
		}
		ctype_free ($1);
	  }
	| declaration_specifiers ';'
	  {
		ctype_free ($1);
	  }
	;

declaration_specifiers
	: storage_class_specifier declaration_specifiers
	  {
		$$ = $2;
		$$->storage_class_specifier |= $1;
	  }
	| storage_class_specifier
	  {
		$$ = gi_source_type_new (CTYPE_INVALID);
		$$->storage_class_specifier |= $1;
	  }
	| type_specifier declaration_specifiers
	  {
		$$ = $1;
		$$->base_type = $2;
	  }
	| type_specifier
	| type_qualifier declaration_specifiers
	  {
		$$ = $2;
		$$->type_qualifier |= $1;
	  }
	| type_qualifier
	  {
		$$ = gi_source_type_new (CTYPE_INVALID);
		$$->type_qualifier |= $1;
	  }
	| function_specifier declaration_specifiers
	  {
		$$ = $2;
		$$->function_specifier |= $1;
	  }
	| function_specifier
	  {
		$$ = gi_source_type_new (CTYPE_INVALID);
		$$->function_specifier |= $1;
	  }
	;

init_declarator_list
	: init_declarator
	  {
		$$ = g_list_append (NULL, $1);
	  }
	| init_declarator_list ',' init_declarator
	  {
		$$ = g_list_append ($1, $3);
	  }
	;

init_declarator
	: declarator
	| declarator '=' initializer
	;

storage_class_specifier
	: TYPEDEF
	  {
		$$ = STORAGE_CLASS_TYPEDEF;
	  }
	| EXTERN
	  {
		$$ = STORAGE_CLASS_EXTERN;
	  }
	| STATIC
	  {
		$$ = STORAGE_CLASS_STATIC;
	  }
	| AUTO
	  {
		$$ = STORAGE_CLASS_AUTO;
	  }
	| REGISTER
	  {
		$$ = STORAGE_CLASS_REGISTER;
	  }
	;

type_specifier
	: VOID
	  {
		$$ = gi_source_type_new (CTYPE_VOID);
	  }
	| CHAR
	  {
		$$ = gi_source_basic_type_new ("char");
	  }
	| SHORT
	  {
		$$ = gi_source_basic_type_new ("short");
	  }
	| INT
	  {
		$$ = gi_source_basic_type_new ("int");
	  }
	| LONG
	  {
		$$ = gi_source_basic_type_new ("long");
	  }
	| FLOAT
	  {
		$$ = gi_source_basic_type_new ("float");
	  }
	| DOUBLE
	  {
		$$ = gi_source_basic_type_new ("double");
	  }
	| SIGNED
	  {
		$$ = gi_source_basic_type_new ("signed");
	  }
	| UNSIGNED
	  {
		$$ = gi_source_basic_type_new ("unsigned");
	  }
	| BOOL
	  {
		$$ = gi_source_basic_type_new ("bool");
	  }
	| struct_or_union_specifier
	| enum_specifier
	| typedef_name
	  {
		$$ = gi_source_typedef_new ($1);
		g_free ($1);
	  }
	;

struct_or_union_specifier
	: struct_or_union identifier_or_typedef_name '{' struct_declaration_list '}'
	  {
		$$ = $1;
		$$->name = $2;
		$$->child_list = $4;

		GISourceSymbol *sym = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		if ($$->type == CTYPE_STRUCT) {
			sym->type = CSYMBOL_TYPE_STRUCT;
		} else if ($$->type == CTYPE_UNION) {
			sym->type = CSYMBOL_TYPE_UNION;
		} else {
			g_assert_not_reached ();
		}
		sym->ident = g_strdup ($$->name);
		sym->base_type = gi_source_type_copy ($$);
		gi_source_scanner_add_symbol (scanner, sym);
		gi_source_symbol_unref (sym);
	  }
	| struct_or_union '{' struct_declaration_list '}'
	  {
		$$ = $1;
		$$->child_list = $3;
	  }
	| struct_or_union identifier_or_typedef_name
	  {
		$$ = $1;
		$$->name = $2;
	  }
	;

struct_or_union
	: STRUCT
	  {
		$$ = gi_source_struct_new (NULL);
	  }
	| UNION
	  {
		$$ = gi_source_union_new (NULL);
	  }
	;

struct_declaration_list
	: struct_declaration
	| struct_declaration_list struct_declaration
	  {
		$$ = g_list_concat ($1, $2);
	  }
	;

struct_declaration
	: specifier_qualifier_list struct_declarator_list ';'
	  {
		GList *l;
		$$ = NULL;
		for (l = $2; l != NULL; l = l->next) {
			GISourceSymbol *sym = l->data;
			if ($1->storage_class_specifier & STORAGE_CLASS_TYPEDEF) {
				sym->type = CSYMBOL_TYPE_TYPEDEF;
			}
			gi_source_symbol_merge_type (sym, gi_source_type_copy ($1));
			$$ = g_list_append ($$, sym);
		}
		ctype_free ($1);
	  }
	;

specifier_qualifier_list
	: type_specifier specifier_qualifier_list
	  {
		$$ = $1;
		$$->base_type = $2;
	  }
	| type_specifier
	| type_qualifier specifier_qualifier_list
	  {
		$$ = $2;
		$$->type_qualifier |= $1;
	  }
	| type_qualifier
	  {
		$$ = gi_source_type_new (CTYPE_INVALID);
		$$->type_qualifier |= $1;
	  }
	;

struct_declarator_list
	: struct_declarator
	  {
		$$ = g_list_append (NULL, $1);
	  }
	| struct_declarator_list ',' struct_declarator
	  {
		$$ = g_list_append ($1, $3);
	  }
	;

struct_declarator
	: /* empty, support for anonymous structs and unions */
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| declarator
	| ':' constant_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
	  }
	| declarator ':' constant_expression
	;

enum_specifier
	: ENUM identifier_or_typedef_name '{' enumerator_list '}'
	  {
		$$ = gi_source_enum_new ($2);
		$$->child_list = $4;
		last_enum_value = -1;
	  }
	| ENUM '{' enumerator_list '}'
	  {
		$$ = gi_source_enum_new (NULL);
		$$->child_list = $3;
		last_enum_value = -1;
	  }
	| ENUM identifier_or_typedef_name '{' enumerator_list ',' '}'
	  {
		$$ = gi_source_enum_new ($2);
		$$->child_list = $4;
		last_enum_value = -1;
	  }
	| ENUM '{' enumerator_list ',' '}'
	  {
		$$ = gi_source_enum_new (NULL);
		$$->child_list = $3;
		last_enum_value = -1;
	  }
	| ENUM identifier_or_typedef_name
	  {
		$$ = gi_source_enum_new ($2);
	  }
	;

enumerator_list
	: enumerator
	  {
		$$ = g_list_append (NULL, $1);
	  }
	| enumerator_list ',' enumerator
	  {
		$$ = g_list_append ($1, $3);
	  }
	;

enumerator
	: identifier
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_OBJECT);
		$$->ident = $1;
		$$->const_int_set = TRUE;
		$$->const_int = ++last_enum_value;
		g_hash_table_insert (const_table, g_strdup ($$->ident), gi_source_symbol_ref ($$));
	  }
	| identifier '=' constant_expression
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_OBJECT);
		$$->ident = $1;
		$$->const_int_set = TRUE;
		$$->const_int = $3->const_int;
		last_enum_value = $$->const_int;
		g_hash_table_insert (const_table, g_strdup ($$->ident), gi_source_symbol_ref ($$));
	  }
	;

type_qualifier
	: CONST
	  {
		$$ = TYPE_QUALIFIER_CONST;
	  }
	| RESTRICT
	  {
		$$ = TYPE_QUALIFIER_RESTRICT;
	  }
	| VOLATILE
	  {
		$$ = TYPE_QUALIFIER_VOLATILE;
	  }
	;

function_specifier
	: INLINE
	  {
		$$ = FUNCTION_INLINE;
	  }
	;

declarator
	: pointer direct_declarator
	  {
		$$ = $2;
		gi_source_symbol_merge_type ($$, $1);
	  }
	| direct_declarator
	;

direct_declarator
	: identifier
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		$$->ident = $1;
	  }
	| '(' declarator ')'
	  {
		$$ = $2;
	  }
	| direct_declarator '[' assignment_expression ']'
	  {
		$$ = $1;
		gi_source_symbol_merge_type ($$, gi_source_array_new ());
	  }
	| direct_declarator '[' ']'
	  {
		$$ = $1;
		gi_source_symbol_merge_type ($$, gi_source_array_new ());
	  }
	| direct_declarator '(' parameter_type_list ')'
	  {
		GISourceType *func = gi_source_function_new ();
		// ignore (void) parameter list
		if ($3 != NULL && ($3->next != NULL || ((GISourceSymbol *) $3->data)->base_type->type != CTYPE_VOID)) {
			func->child_list = $3;
		}
		$$ = $1;
		gi_source_symbol_merge_type ($$, func);
	  }
	| direct_declarator '(' identifier_list ')'
	  {
		GISourceType *func = gi_source_function_new ();
		func->child_list = $3;
		$$ = $1;
		gi_source_symbol_merge_type ($$, func);
	  }
	| direct_declarator '(' ')'
	  {
		GISourceType *func = gi_source_function_new ();
		$$ = $1;
		gi_source_symbol_merge_type ($$, func);
	  }
	;

pointer
	: '*' type_qualifier_list
	  {
		$$ = gi_source_pointer_new (NULL);
		$$->type_qualifier = $2;
	  }
	| '*'
	  {
		$$ = gi_source_pointer_new (NULL);
	  }
	| '*' type_qualifier_list pointer
	  {
		$$ = gi_source_pointer_new ($3);
		$$->type_qualifier = $2;
	  }
	| '*' pointer
	  {
		$$ = gi_source_pointer_new ($2);
	  }
	;

type_qualifier_list
	: type_qualifier
	| type_qualifier_list type_qualifier
	  {
		$$ = $1 | $2;
	  }
	;

parameter_type_list
	: parameter_list
	| parameter_list ',' ELLIPSIS
	;

parameter_list
	: parameter_declaration
	  {
		$$ = g_list_append (NULL, $1);
	  }
	| parameter_list ',' parameter_declaration
	  {
		$$ = g_list_append ($1, $3);
	  }
	;

parameter_declaration
	: declaration_specifiers declarator
	  {
		$$ = $2;
		gi_source_symbol_merge_type ($$, $1);
	  }
	| declaration_specifiers abstract_declarator
	  {
		$$ = $2;
		gi_source_symbol_merge_type ($$, $1);
	  }
	| declaration_specifiers
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		$$->base_type = $1;
	  }
	;

identifier_list
	: identifier
	  {
		GISourceSymbol *sym = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		sym->ident = $1;
		$$ = g_list_append (NULL, sym);
	  }
	| identifier_list ',' identifier
	  {
		GISourceSymbol *sym = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		sym->ident = $3;
		$$ = g_list_append ($1, sym);
	  }
	;

type_name
	: specifier_qualifier_list
	| specifier_qualifier_list abstract_declarator
	;

abstract_declarator
	: pointer
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		gi_source_symbol_merge_type ($$, $1);
	  }
	| direct_abstract_declarator
	| pointer direct_abstract_declarator
	  {
		$$ = $2;
		gi_source_symbol_merge_type ($$, $1);
	  }
	;

direct_abstract_declarator
	: '(' abstract_declarator ')'
	  {
		$$ = $2;
	  }
	| '[' ']'
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		gi_source_symbol_merge_type ($$, gi_source_array_new ());
	  }
	| '[' assignment_expression ']'
	  {
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		gi_source_symbol_merge_type ($$, gi_source_array_new ());
	  }
	| direct_abstract_declarator '[' ']'
	  {
		$$ = $1;
		gi_source_symbol_merge_type ($$, gi_source_array_new ());
	  }
	| direct_abstract_declarator '[' assignment_expression ']'
	  {
		$$ = $1;
		gi_source_symbol_merge_type ($$, gi_source_array_new ());
	  }
	| '(' ')'
	  {
		GISourceType *func = gi_source_function_new ();
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		gi_source_symbol_merge_type ($$, func);
	  }
	| '(' parameter_type_list ')'
	  {
		GISourceType *func = gi_source_function_new ();
		// ignore (void) parameter list
		if ($2 != NULL && ($2->next != NULL || ((GISourceSymbol *) $2->data)->base_type->type != CTYPE_VOID)) {
			func->child_list = $2;
		}
		$$ = gi_source_symbol_new (CSYMBOL_TYPE_INVALID);
		gi_source_symbol_merge_type ($$, func);
	  }
	| direct_abstract_declarator '(' ')'
	  {
		GISourceType *func = gi_source_function_new ();
		$$ = $1;
		gi_source_symbol_merge_type ($$, func);
	  }
	| direct_abstract_declarator '(' parameter_type_list ')'
	  {
		GISourceType *func = gi_source_function_new ();
		// ignore (void) parameter list
		if ($3 != NULL && ($3->next != NULL || ((GISourceSymbol *) $3->data)->base_type->type != CTYPE_VOID)) {
			func->child_list = $3;
		}
		$$ = $1;
		gi_source_symbol_merge_type ($$, func);
	  }
	;

typedef_name
	: TYPEDEF_NAME
	  {
		$$ = g_strdup (yytext);
	  }
	;

initializer
	: assignment_expression
	| '{' initializer_list '}'
	| '{' initializer_list ',' '}'
	;

initializer_list
	: initializer
	| initializer_list ',' initializer
	;

/* A.2.3 Statements. */

statement
	: labeled_statement
	| compound_statement
	| expression_statement
	| selection_statement
	| iteration_statement
	| jump_statement
	;

labeled_statement
	: identifier_or_typedef_name ':' statement
	| CASE constant_expression ':' statement
	| DEFAULT ':' statement
	;

compound_statement
	: '{' '}'
	| '{' block_item_list '}'
	;

block_item_list
	: block_item
	| block_item_list block_item
	;

block_item
	: declaration
	| statement
	;

expression_statement
	: ';'
	| expression ';'
	;

selection_statement
	: IF '(' expression ')' statement
	| IF '(' expression ')' statement ELSE statement
	| SWITCH '(' expression ')' statement
	;

iteration_statement
	: WHILE '(' expression ')' statement
	| DO statement WHILE '(' expression ')' ';'
	| FOR '(' ';' ';' ')' statement
	| FOR '(' expression ';' ';' ')' statement
	| FOR '(' ';' expression ';' ')' statement
	| FOR '(' expression ';' expression ';' ')' statement
	| FOR '(' ';' ';' expression ')' statement
	| FOR '(' expression ';' ';' expression ')' statement
	| FOR '(' ';' expression ';' expression ')' statement
	| FOR '(' expression ';' expression ';' expression ')' statement
	;

jump_statement
	: GOTO identifier_or_typedef_name ';'
	| CONTINUE ';'
	| BREAK ';'
	| RETURN ';'
	| RETURN expression ';'
	;

/* A.2.4 External definitions. */

translation_unit
	: external_declaration
	| translation_unit external_declaration
	;

external_declaration
	: function_definition
	| declaration
	| macro
	;

function_definition
	: declaration_specifiers declarator declaration_list compound_statement
	| declaration_specifiers declarator compound_statement
	;

declaration_list
	: declaration
	| declaration_list declaration
	;

/* Macros */

function_macro
	: FUNCTION_MACRO
	  {
		$$ = g_strdup (yytext + strlen ("#define "));
	  }
	;

object_macro
	: OBJECT_MACRO
	  {
		$$ = g_strdup (yytext + strlen ("#define "));
	  }
	;

function_macro_define
	: function_macro '(' identifier_list ')'
	;

object_macro_define
	: object_macro constant_expression
	  {
		if ($2->const_int_set || $2->const_string != NULL) {
			$2->ident = $1;
			gi_source_scanner_add_symbol (scanner, $2);
			gi_source_symbol_unref ($2);
		}
	  }
	;

macro
	: function_macro_define
	| object_macro_define
	| error
	;

%%
static void
yyerror (GISourceScanner *scanner, const char *s)
{
  /* ignore errors while doing a macro scan as not all object macros
   * have valid expressions */
  if (!scanner->macro_scan)
    {
      fprintf(stderr, "%s:%d: %s\n",
	      scanner->current_filename, lineno, s);
    }
}

gboolean
gi_source_scanner_parse_file (GISourceScanner *scanner, FILE *file)
{
  g_return_val_if_fail (file != NULL, FALSE);
  
  const_table = g_hash_table_new_full (g_str_hash, g_str_equal,
				       g_free, (GDestroyNotify)gi_source_symbol_unref);
  
  lineno = 1;
  yyin = file;
  yyparse (scanner);
  
  g_hash_table_destroy (const_table);
  const_table = NULL;
  
  yyin = NULL;

  return TRUE;
}

gboolean
gi_source_scanner_lex_filename (GISourceScanner *scanner, const gchar *filename)
{
  yyin = fopen (filename, "r");

  while (yylex (scanner) != YYEOF)
    ;

  fclose (yyin);
  
  return TRUE;
}