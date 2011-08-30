%%------------------------------------------------------------------------------
%% @author Francesca Gangemi <francesca@erlang-consulting.com>
%% @doc Event Handler 
%% @end
%%------------------------------------------------------------------------------
-module(ecron_event_handler_test).
-author('francesca@erlang-consulting.com').
-copyright('Erlang Training & Consulting Ltd.').


-behaviour(gen_event).

-export([init/1, 
         handle_event/2,
         handle_call/2,
         handle_info/2,
         code_change/3,
         terminate/2]).

init(_Args) ->
    ets:new(event_test, [named_table, public, duplicate_bag]),
    {ok, []}.


handle_event(Event, State) ->
    ets:insert(event_test, Event),
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
    ets:delete(event_test),
    ok.

%%------------------------------------------------------------------------------
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed
%% @end
%%------------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
