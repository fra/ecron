%%------------------------------------------------------------------------------
%% @author Ulf Wiger <ulf.wiger@erlang-solutions.com>
%% @doc Ecron counterparts of the built-in time functions.
%%
%% This module wraps the standard time functions, `erlang:localtime()',
%% `erlang:universaltime()', `erlang:now()' and `os:timestamp()'.
%%
%% The reason for this is to enable mocking to simulate time within ecron.
%% @end
%%
-module(ecron_time).
-export([localtime/0,
	 universaltime/0,
	 now/0,
	 timestamp/0]).


localtime() ->
    erlang:localtime().

universaltime() ->
    erlang:universaltime().

now() ->
    erlang:now().

timestamp() ->
    os:timestamp().
