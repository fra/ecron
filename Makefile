.PHONY: all compile clean eunit test doc dialyzer

all: compile eunit test doc

compile:
	rebar compile

clean:
	rebar clean

eunit:
	rebar eunit

test: eunit

doc:
	rebar doc

dialyzer: compile
	rebar skip_deps=true dialyze

