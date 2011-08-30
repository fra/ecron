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
-module(ecron_event_sup).
-author('francesca@erlang-consulting.com').
-copyright('Erlang Solutions Ltd.').


-behaviour(supervisor).

%% API
-export([start_handler/2,
         stop_handler/1,
         list_handlers/0
        ]).

-export([start_link/0,
        init/1]).


%%==============================================================================
%% API functions
%%==============================================================================
%%------------------------------------------------------------------------------
%% @spec start_handler(Handler, Args) -> {ok,Pid} | {error,Error}
%% @doc Starts a child that will add a new event handler
%% @end
%%------------------------------------------------------------------------------
start_handler(Handler, Args) ->
    supervisor:start_child(?MODULE, [Handler, Args]).

%%------------------------------------------------------------------------------
%% @spec stop_handler(Pid) -> ok
%% @doc Stop the child with the given Pid. It will terminate the associated 
%%      event handler
%% @end
%%------------------------------------------------------------------------------
stop_handler(Pid) ->
    Children = supervisor:which_children(?MODULE),
    case lists:keysearch(Pid, 2, Children) of
        {value, {_, Pid, _, _}} ->
            Pid ! terminate,
            ok;
        false ->
            ok
    end.
            
%%------------------------------------------------------------------------------
%% @spec list_handlers() -> [{Pid, Handler}]
%%       Handler = Module | {Module,Id}
%%       Module = atom()
%%       Id = term()
%%       Pid = pid()
%% @doc Returns a list of all event handlers installed by the 
%%      <code>start_handler/2</code> API 
%% @end
%%------------------------------------------------------------------------------
list_handlers() ->
    Children = supervisor:which_children(?MODULE),
    lists:foldl(fun({_, Pid, worker, [ecron_event_handler_controller]}, H) ->
                        Pid ! {get_handler, self()},
                        receive 
                            {handler, Handler} ->
                                [{Pid, Handler}|H]
                        after 3000 ->
                                [{Pid, undefined}|H]
                        end
                end, [], Children).


%%------------------------------------------------------------------------------
%% @spec init(Args) -> {ok,{SupFlags,  [ChildSpec]}} |
%%                     ignore                         
%% @doc Whenever a supervisor is started using supervisor:start_link/2,3, 
%% this function is called by the new process to find out about restart strategy,
%% maximum restart frequency and child specifications. 
%% @end
%%------------------------------------------------------------------------------
init(_Args) ->
  
    Child_Spec = [{ecron_event_handler_controller,
                   {ecron_event_handler_controller, start_link, []},
                   temporary, 5000, worker, 
                   [ecron_event_handler_controller]}],
    {ok,{{simple_one_for_one,3,1}, Child_Spec}}.


%%------------------------------------------------------------------------------
%% @spec start_link() -> {ok,Pid} | ignore | {error,Error}
%% @doc Starts the supervisor
%% @end
%%------------------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).







