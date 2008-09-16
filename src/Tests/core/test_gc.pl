/*  $Id$

    Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        wielemak@science.uva.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2008, University of Amsterdam

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

:- module(test_gc, [test_gc/0]).
:- use_module(library(plunit)).

/** <module> Test garbage collection

This unit contains small tests for the garbage collector.
*/

test_gc :-
	run_tests([ gc_leak,
		    gc_reset,
		    gc_crash,
		    gc_mark
		  ]).

:- module_transparent
	space/3,
	nospace/1.

space(T, G) :-
	garbage_collect,
	statistics(trailused, T),
	statistics(globalused, G).

must_space(T0, G0) :-
	space(T1, G1),
	(   T0 == T1,
	    G0 == G1
	->  true
	;   T is T1-T0,
	    G is G1-G0,
	    format(user_error, 'Used ~D+~D~n', [T,G]),
	    fail
	).

space(Goal, T, G) :-
	space(T0,G0),
	Goal,
	space(T1,G1),
	T is T1-T0,
	G is G1-G0.

nospace(Goal) :-
	space(Goal, T, G),
	(   T == 0, G == 0
	->  true
	;   format(user_error, 'Used ~D+~D~n', [T,G]),
	    fail
	).

:- begin_tests(gc_leak, [sto(rational_trees)]).

det_freeze_loop(N, T) :-
	(   succ(N2, N)
	->  freeze(X, true),
	    X = a,
	    det_freeze_loop(N2, T)
	;   garbage_collect,
	    statistics(trailused, T)
	).

early_reset :-
	early_reset(_).

early_reset(X) :- space(T,G), length(X, 10), must_space(T,G), !.
early_reset(_) :- fail.

test(det_freeze_no_space) :-
	garbage_collect,
	statistics(trailused, T0),
	det_freeze_loop(1000, T1),
	T is T1 - T0,
	T < 100.			% A small constant use is ok
test(early_reset) :-
	early_reset.

:- end_tests(gc_leak).

:- begin_tests(gc_reset).

deep_reset :-
        X = a(A),
        deep_reset(A), !,
        X == a(42).

deep_reset(A) :-
        (   A = 42, garbage_collect
        ;   true
        ).

test(deep_reset) :- deep_reset.


:- end_tests(gc_reset).

:- begin_tests(gc_crash).

:- set_prolog_flag(double_quotes, string).

t1 :-
	garbage_collect,
	t("hello world").

t("hello world").

test(b_string) :-
	t1.
test(wakeup_two) :-
	freeze(V1, true),
	freeze(V2, (garbage_collect,V2==y)),
	(   x(V1,V2) = x(a,b)
	;   x(V1,V2) = x(x,y)
	).

:- end_tests(gc_crash).


:- begin_tests(gc_mark).

test(s_list, true) :-			% S_NEXTCLAUSE must mark args of next
	length(_List, N),		% clause (broken in 5.7.0)
	garbage_collect,
	N == 4, !.
test(s_fredo, true) :-	
	A = a(1,2,3,4,5,6),
	arg(_I, A, N),
	garbage_collect,
	N == 5, !.

:- end_tests(gc_mark).
