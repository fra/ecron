%%------------------------------------------------------------------------------
%% @author Francesca Gangemi <francesca.gangemi@erlang-solutions.com>
%% @doc Event Handler 
%% @end

%%% Copyright (c) 2009-2010  Erlang Solutions 
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%% * Redistributions of source code must retain the above copyright
%%%   notice, this list of conditions and the following disclaimer. 
%%% * Redistributions in binary form must reproduce the above copyright
%%%   notice, this list of conditions and the following disclaimer in the
%%%   documentation and/or other materials provided with the distribution.
%%% * Neither the name of the Erlang Solutions nor the names of its
%%%   contributors may be used to endorse or promote products
%%%   derived from this software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%%% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
%%% BE  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
%%% BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
%%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
%%% OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
%%% ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%------------------------------------------------------------------------------
-module(ecron_event).
-author('francesca.gangemi@erlang-solutions.com').
-copyright('Erlang Solutions Ltd.').


-behaviour(gen_event).

-export([init/1, 
         handle_event/2,
         handle_call/2,
         handle_info/2,
         code_change/3,
         terminate/2]).

init(_Args) ->
    {ok, []}.

handle_event({mfa_result, ok, {Schedule, MFA},
              DueDateTime, ExecutionDateTime}, State) ->
    io:format("***Executed ~p at ~w expected at ~w Result = ~p~n", 
              [{Schedule, MFA},
               ExecutionDateTime, DueDateTime, ok]),
    {ok, State};

handle_event({mfa_result, {ok, Data}, {Schedule, MFA},
              DueDateTime, ExecutionDateTime}, State) ->
    io:format("***Executed ~p at ~w expected at ~w Result = ~p~n", 
              [{Schedule, MFA},
               ExecutionDateTime, DueDateTime, {ok, Data}]),
    {ok, State};

handle_event({mfa_result, {apply, Fun}, {Schedule, MFA},
              DueDateTime, ExecutionDateTime}, State) ->
    io:format("***Executed ~p at ~w expected at ~w Result = ~p~n", 
              [{Schedule, MFA},
               ExecutionDateTime, DueDateTime, {apply, Fun}]),
    {ok, State};

handle_event({mfa_result, {error, Reason}, {Schedule, MFA},
              DueDateTime, ExecutionDateTime}, State) ->
    io:format("***Executed ~p at ~w expected at ~w Result = ~p~n", 
              [{Schedule, MFA},
               ExecutionDateTime, DueDateTime, {error, Reason}]),
    {ok, State};

handle_event({mfa_result, Result, {Schedule, MFA},
              DueDateTime, ExecutionDateTime}, State) ->
    io:format("***Executed ~p at ~w expected at ~w Result = ~p~n", 
              [{Schedule, MFA},
               ExecutionDateTime, DueDateTime, Result]),
    {ok, State};

handle_event({fun_result, Result, {Schedule, MFA},
              DueDateTime, ExecutionDateTime}, State) ->
    io:format("***Executed fun from ~p at ~w expected at ~w Result = ~p~n", 
              [{Schedule, MFA},
               ExecutionDateTime, DueDateTime, Result]),
    {ok, State};

handle_event({retry, {Schedule, MFA}, undefined, DueDateTime}, State) ->
    io:format("***Retry ~p expected at ~w ~n", 
              [{Schedule, MFA}, DueDateTime]),
    {ok, State};

handle_event({retry, {Schedule, MFA}, Fun, DueDateTime}, State) ->
    io:format("***Retry fun ~p from ~p expected at ~w ~n", 
              [Fun, {Schedule, MFA}, DueDateTime]),
    {ok, State};

handle_event({max_retry, {Schedule, MFA}, undefined, DueDateTime}, State) ->
    io:format("***Max Retry reached ~p expected at ~p ~n", 
              [{Schedule, MFA}, DueDateTime]),
    {ok, State};

handle_event({max_retry, {Schedule, MFA}, Fun, DueDateTime}, State) ->
    io:format("***Max Retry reached fun ~p from ~p expected at ~p ~n", 
              [Fun, {Schedule, MFA}, DueDateTime]),
    {ok, State};

handle_event(Event, State) ->
    io:format("***Event =~p~n",[Event]),
    {ok, State}.

%%------------------------------------------------------------------------------
%% @spec handle_call(Request, State) -> {ok, Reply, State} |
%%                                      {swap_handler, Reply, Args1, State1,
%%                                       Mod2, Args2} |
%%                                      {remove_handler, Reply}
%% @doc Whenever an event manager receives a request sent using
%% gen_event:call/3,4, this function is called for the specified event
%% handler to handle the request.
%% @end
%%------------------------------------------------------------------------------
handle_call(_Request, State) ->
  Reply = ok,
  {ok, Reply, State}.

%%------------------------------------------------------------------------------
%% @spec handle_info(Info, State) -> {ok, State} |
%%                                   {swap_handler, Args1, State1, Mod2, Args2} |
%%                                    remove_handler
%% @doc This function is called for each installed event handler when
%% an event manager receives any other message than an event or a synchronous
%% request (or a system message).
%% @end
%%------------------------------------------------------------------------------
handle_info(_Info, State) ->
  {ok, State}.

%%------------------------------------------------------------------------------
%% @spec terminate(Reason, State) -> void()
%% @doc Whenever an event handler is deleted from an event manager,
%% this function is called. It should be the opposite of Module:init/1 and
%% do any necessary cleaning up.
%% @end
%%------------------------------------------------------------------------------
terminate(_Reason, _State) ->
  ok.

%%------------------------------------------------------------------------------
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed
%% @end
%%------------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
