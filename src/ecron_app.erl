%%%-----------------------------------------------------------------------------
%%% @author Francesca Gangemi <francesca.gangemi@erlang-solutions.com>
%%% @doc Ecron application
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

-module(ecron_app).
-author('francesca.gangemi@erlang-solutions.com').
-copyright('Erlang Solutions Ltd.').

-export([start/2,
         stop/1]).

-include("ecron.hrl").

%%==============================================================================
%% API functions
%%==============================================================================
%%------------------------------------------------------------------------------
%% @spec start(_Type, _Args) -> Result
%% 	_Type = atom()
%% 	_Args = list()
%% 	Result = {ok, pid()} | {timeout, BatTabList} | {error, Reason}
%% @doc Start the ecron application
%% @end
%%------------------------------------------------------------------------------
start(_Type, _Args) ->
    case mnesia:wait_for_tables([?JOB_TABLE, ?JOB_COUNTER],10000) of
        ok ->
            {ok, Pid} = ecron_sup:start_link(),
            case application:get_env(ecron, event_handlers) of
                undefined      -> EH = [];
                {ok, Handlers} -> EH = Handlers
            end,
            lists:foreach(
              fun({Handler, Args}) ->
                      {ok, _} = ecron_event_sup:start_handler(Handler, Args)
              end, EH),
            {ok, Pid};
        Error ->
            Error
    end.    


%%------------------------------------------------------------------------------
%% @spec stop(_Args) -> Result
%% 	_Args = list()
%% @doc Stop the ecron application
%% @end
%%------------------------------------------------------------------------------
stop(_Args) ->
    ok.

