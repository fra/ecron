%%%-----------------------------------------------------------------------------
%%% @author Francesca Gangemi <francesca.gangemi@erlang-solutions.com>
%%% @doc Supervisor module
%%% @end

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
%%%-----------------------------------------------------------------------------
-module(ecron_sup).
-author('francesca.gangemi@erlang-solutions.com').
-copyright('Erlang Solutions Ltd.').

-export([start_link/0,
        init/1]).

-include("ecron.hrl").

%%==============================================================================
%% API functions
%%==============================================================================

%%------------------------------------------------------------------------------
%% @spec start_link() -> {ok,Pid} | ignore | {error,Error}
%% @doc Starts the supervisor
%% @end
%%------------------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


%%==============================================================================
%% Supervisor callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @spec init(Args) -> {ok,{SupFlags,  [ChildSpec]}} |
%%                     ignore                         
%% @doc Whenever a supervisor is started using supervisor:start_link/2,3, 
%% this function is called by the new process to find out about restart strategy,
%% maximum restart frequency and child specifications. 
%% @end
%%------------------------------------------------------------------------------
init(_Args) ->
    EventManager = {?EVENT_MANAGER,
                    {gen_event, start_link, [{local, ?EVENT_MANAGER}]},
                    permanent, 10000, worker, [dynamic]},

    Ecron = {ecron_server, {ecron, start_link, []},
              permanent, 10000, worker, [ecron]},

    EventSup = {ecron_event_sup,
                          {ecron_event_sup, start_link, []},
                          permanent, 10000, supervisor, [ecron_event_sup]},

     {ok,{{one_for_one,3,1}, [EventManager, EventSup, Ecron]}}.

            
