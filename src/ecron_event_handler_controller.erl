%%------------------------------------------------------------------------------
%% @author Francesca Gangemi <francesca.gangemi@erlang-solutions.com>
%% @doc
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
-module(ecron_event_handler_controller).
-author('francesca.gangemi@erlang-solutions.com').
-copyright('Erlang Solutions Ltd.').

-export([start_link/2,
         init/3,
         system_continue/3,
         system_terminate/4
        ]).

-include("ecron.hrl").

-record(state,{handler, parent, debug}).

%%------------------------------------------------------------------------------
%% @spec start_link(Handler, Args) -> term() | {error, Reason}
%% @doc
%% @end
%%------------------------------------------------------------------------------
start_link(Handler, Args) ->
   proc_lib:start_link(?MODULE, init, [self(), Handler, Args]).


init(Parent, Handler, Args) ->
    ok = gen_event:add_sup_handler(?EVENT_MANAGER, Handler, Args),
    proc_lib:init_ack(Parent, {ok, self()}),
    loop(#state{handler = Handler,
                parent = Parent,
                debug = sys:debug_options([])}).

loop(State) ->
    receive
        {system, From, Msg} ->
            handle_system_message(State, From, Msg),
            loop(State);
        {gen_event_EXIT, _Handler, normal} ->
            exit(normal);
        {gen_event_EXIT, _Handler, shutdown} ->
            exit(normal);
        {gen_event_EXIT, _Handler, {swapped, _NewHandler, _Pid}} ->
            loop(State);
        {gen_event_EXIT, Handler, Reason} ->
            error_logger:error_msg(
	      "Handler ~p terminates with Reason=~p~nRestart it...",
	      [Handler, Reason]),
            exit({handler_died, Reason});
        terminate ->
            exit(normal);
        {get_handler, From} ->
            From ! {handler, State#state.handler},
            loop(State);
        _E ->
            loop(State)
    end.



handle_system_message(State, From, Msg) ->
    _ = sys:handle_debug(State#state.debug, fun write_debug/3, State,
			 {system, From, Msg}),
    Parent = State#state.parent,
    Debug = State#state.debug,
    sys:handle_system_msg(Msg, From, Parent, ?MODULE, Debug, State).

system_continue(_Parent, _Deb, State) ->
    loop(State).

-spec system_terminate(any(), any(), any(), any()) -> no_return().
%%
system_terminate(Reason, _Parent, _Deb, _State) ->
    exit(Reason).

write_debug(Dev, Event, Name) ->
    io:format(Dev, "~p event = ~p~n", [Name, Event]).
