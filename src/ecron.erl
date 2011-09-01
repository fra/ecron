%%------------------------------------------------------------------------------
%% @author Francesca Gangemi <francesca.gangemi@erlang-solutions.com>
%% @doc The Ecron API module.
%%
%% The Ecron application executes scheduled functions.
%% A list of functions to execute might be specified in the ecron application
%% resource file as value of the `scheduled' environment variable.
%%
%% Each entry specifies a job and must contain the scheduled time and a MFA
%% tuple `{Module, Function, Arguments}'.
%% It's also possible to configure options for a retry algorithm to run in case
%% MFA fails.
%% <pre>
%% Job =  {{Date, Time}, MFA, Retry, Seconds} |
%%        {{Date, Time}, MFA}
%% </pre>
%% `Seconds = integer()' is the retry interval.
%%
%% `Retry = integer() | infinity' is the number of times to retry.
%%
%%
%% Example of ecron.app
%% <pre>
%% ...
%% {env,[{scheduled,
%%        [{{{ '*', '*', '*'}, {0 ,0,0}}, {my_mod, my_fun1, Args}},
%%         {{{ '*', 12 ,  25}, {0 ,0,0}}, {my_mod, my_fun2, Args}},
%%         {{{ '*', 1  ,  1 }, {0 ,0,0}}, {my_mod, my_fun3, Args}, infinity, 60},
%%         {{{2010, 1  ,  1 }, {12,0,0}}, {my_mod, my_fun3, Args}},
%%         {{{ '*', 12 ,last}, {0 ,0,0}}, {my_mod, my_fun4, Args}]}]},
%% ...
%% </pre>
%% Once the ecron application is started, it's possible to dynamically add new
%% jobs using the `ecron:insert/2' or  `ecron:insert/4'
%% API.
%%
%% The MFA is executed when a task is set to run.
%% The MFA has to return `ok', `{ok, Data}', `{apply, fun()}'
%% or `{error, Reason}'.
%% If `{error, Reason}' is returned and the job was defined with retry options
%% (Retry and Seconds were specified together with the MFA) then ecron will try
%% to execute MFA later according to the given configuration.
%%
%% The MFA may return `{apply, fun()}' where `fun()' has arity zero.
%%
%% `fun' will be immediately executed after MFA execution.
%% The `fun' has to return `ok', `{ok, Data}' or `{error, Reason}'.
%%
%% If the MFA or `fun' terminates abnormally or returns an invalid
%% data type (not `ok', `{ok, Data}' or `{error, Reason}'), an event
%% is forwarded to the event manager and no retries are executed.
%%
%% If the return value of the fun is `{error, Reason}' and retry
%% options were given in the job specification then the `fun' is
%% rescheduled to be executed after the configurable amount of time.
%%
%% Data which does not change between retries of the `fun'
%% must be calculated outside the scope of the `fun'.
%% Data which changes between retries has to be calculated within the scope
%% of the `fun'.<br/>
%% In the following example, ScheduleTime will change each time the function is
%% scheduled, while ExecutionTime will change for every retry. If static data
%% has to persist across calls or retries, this is done through a function in
%% the MFA or the fun.
%%
%% <pre>
%% print() ->
%%   ScheduledTime = time(),
%%   {apply, fun() ->
%%       ExecutionTime = time(),
%%       io:format("Scheduled:~p~n",[ScheduledTime]),
%%       io:format("Execution:~p~n",[ExecutionTime]),
%%       {error, retry}
%%   end}.
%% </pre>
%% Event handlers may be configured in the application resource file specifying
%% for each of them, a tuple as the following:
%%
%% <pre>{Handler, Args}
%%
%% Handler = Module | {Module,Id}
%% Module = atom()
%% Id = term()
%% Args = term()
%% </pre>
%% `Module:init/1' will be called to initiate the event handler and
%% its internal state<br/><br/>
%% Example of ecron.app
%% <pre>
%% ...
%% {env, [{event_handlers, [{ecron_event, []}]}]},
%% ...
%% </pre>
%% The API `add_event_handler/2' and
%% `delete_event_handler/1'
%% allow user to dynamically add and remove event handlers.
%%
%% All the configured event handlers will receive the following events:
%%
%% `{mfa_result, Result, {Schedule, {M, F, A}}, DueDateTime, ExecutionDateTime}'
%%  when MFA is  executed.
%%
%% `{fun_result, Result, {Schedule, {M, F, A}}, DueDateTime, ExecutionDateTime}'
%% when `fun' is executed.
%%
%% `{retry, {Schedule, MFA}, Fun, DueDateTime}'
%% when MFA, or `fun', is rescheduled to be executed later after a failure.
%%
%% `{max_retry, {Schedule, MFA}, Fun, DueDateTime}' when MFA,
%% or `fun' has reached maximum number of retry specified when
%% the job was inserted.
%%
%% `Result' is the return value of MFA or `fun'.
%%  If an exception occurs during evaluation of MFA, or `fun', then
%% it's caught and sent in the event.
%% (E.g. <code>Result = {'EXIT',{Reason,Stack}}</code>).
%%
%% `Schedule = {Date, Time}' as given when the job was inserted, E.g.
%% <code> {{'*','*','*'}, {0,0,0}}</code><br/>
%% `DueDateTime = {Date, Time} ' is the exact Date and Time when the MFA,
%% or the `fun', was supposed to run.
%%  E.g. ` {{2010,1,1}, {0,0,0}}'<br/>
%% `ExecutionDateTime = {Date, Time} ' is the exact Date and Time
%% when the MFA, or the `fun', was executed.<br/><br/><br/>
%% If a node is restarted while there are jobs in the list then these jobs are
%% not lost. When Ecron starts it takes a list of scheduled MFA from the
%% environment variable `scheduled' and inserts them into a persistent table
%% (mnesia). If an entry of the scheduled MFA specifies the same parameters
%% values of a job already present in the table then the entry won't be inserted
%% avoiding duplicated jobs. <br/>
%% No duplicated are removed from the MFA list configured in the `
%% scheduled' variable.
%%
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
-module(ecron).
-author('francesca.gangemi@erlang-solutions.com').
-copyright('Erlang Solutions Ltd.').

-behaviour(gen_server).

%% API
-export([install/0,
         install/1,
         start_link/0,
         insert/2,
         insert/4,
         list/0,
         print_list/0,
         execute_all/0,
         refresh/0,
         delete/1,
         delete_all/0,
         add_event_handler/2,
         list_event_handlers/0,
         delete_event_handler/1]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
		 terminate/2,
         code_change/3]).

-export([execute_job/2,
         create_add_job/1]).

-include("ecron.hrl").

%%==============================================================================
%% API functions
%%==============================================================================

%%------------------------------------------------------------------------------
%% @spec start_link() -> {ok,Pid} | ignore | {error,Error}
%% @doc Start the server
%% @private
%% @end
%%------------------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


%%------------------------------------------------------------------------------
%% @spec install() -> ok
%% @doc Create mnesia tables on those nodes where disc_copies resides according
%% to the schema. <br/>
%% Before starting the `ecron' application
%%  for the first time a new database must be created, `mnesia:create_schema/1
%% ' and tables created by `ecron:install/0' or
%%  `ecron:install/1'<br/>
%% E.g. <br/>
%% <pre>
%% >mnesia:create_schema([node()]).
%% >mnesia:start().
%% >ecron:install().
%% </pre>
%% @end
%%------------------------------------------------------------------------------
install() ->
    install(mnesia:table_info(schema,disc_copies)).

%%------------------------------------------------------------------------------
%% @spec install(Nodes) -> ok
%% @doc Create mnesia tables on Nodes.
%% @end
%%------------------------------------------------------------------------------
install(Nodes) ->
    create_table(?JOB_COUNTER, [{disc_copies, Nodes}]),
    create_table(?JOB_TABLE, [{type, ordered_set},
                              {attributes, record_info(fields, job)},
                              {disc_copies, Nodes}]).

%%------------------------------------------------------------------------------
%% @spec add_event_handler(Handler, Args) -> {ok, Pid} | {error, Reason}
%% Handler = Module | {Module,Id}
%% Module = atom()
%% Id = term()
%% Args = term()
%% Pid = pid()
%% @doc Adds a new event handler. The handler is added regardless of whether
%% it's already present, thus duplicated handlers may exist.
%% @end
%%------------------------------------------------------------------------------
add_event_handler(Handler, Args) ->
    ecron_event_sup:start_handler(Handler, Args).

%%------------------------------------------------------------------------------
%% @spec delete_event_handler(Pid) -> ok
%% Pid = pid()
%% @doc Deletes an event handler. Pid is the pid() returned by
%% `add_event_handler/2'.
%% @end
%%------------------------------------------------------------------------------
delete_event_handler(Pid) ->
    ecron_event_sup:stop_handler(Pid).

%%------------------------------------------------------------------------------
%% @spec list_event_handlers() -> [{Pid, Handler}]
%%       Handler = Module | {Module,Id}
%%       Module = atom()
%%       Id = term()
%%       Pid = pid()
%% @doc Returns a list of all event handlers installed by the
%%      `ecron:add_event_handler/2' API or configured in the
%%      `event_handlers' environment variable.
%% @end
%%------------------------------------------------------------------------------
list_event_handlers() ->
    ecron_event_sup:list_handlers().

%%------------------------------------------------------------------------------
%% @spec insert(DateTime, MFA) -> ok
%% DateTime = {Date, Time}
%% Date = {Year, Month, Day} | '*'
%% Time = {Hours, Minutes, Seconds}
%% Year =  integer() | '*'
%% Month = integer() | '*'
%% Day = integer() | '*' | last
%% Hours = integer()
%% Minutes = integer()
%% Seconds = integer()
%% MFA = {Module, Function, Args}
%% @doc Schedules the MFA at the given Date and Time. <br/>
%% Inserts the MFA into the queue to be scheduled at
%% {Year,Month, Day},{Hours, Minutes,Seconds}<br/>
%% <pre>
%% Month = 1..12 | '*'
%% Day = 1..31 | '*' | last
%% Hours = 0..23
%% Minutes = 0..59
%% Seconds = 0..59
%% </pre>
%% If `Day = last' then the MFA will be executed last day of the month.
%%
%% <code>{'*', Time}</code> runs the MFA every day at the given time and it's
%% the same as writing <code>{{'*','*','*'}, Time}</code>.
%%
%% <code>{{'*', '*', Day}, Time}</code> runs the MFA every month at the given
%% Day and Time. It must be `Day = 1..28 | last'
%%
%% <code>{{'*', Month, Day}, Time}</code> runs the MFA every year at the given
%% Month, Day and Time. Day must be valid for the given month or the atom
%% `last'.
%% If `Month = 2' then it must be `Day = 1..28 | last'
%%
%% Combinations of the format <code>{'*', Month, '*'}</code> are not allowed.
%%
%% `{{Year, Month, Day}, Time}' runs the MFA at the given Date and Time.
%%
%% Returns `{error, Reason}' if invalid parameters have been passed.
%% @end
%%------------------------------------------------------------------------------
insert({Date, Time} = _DateTime, MFA) ->
    insert({Date, Time}, MFA, undefined, undefined).

%%------------------------------------------------------------------------------
%% @spec insert(DateTime, MFA, Retry, RetrySeconds) -> ok
%% DateTime = {Date, Time}
%% Date = {Year, Month, Day} | '*'
%% Time = {Hours, Minutes, Seconds}
%% Year =  integer() | '*'
%% Month = integer() | '*'
%% Day = integer() | '*' | last
%% Hours = integer()
%% Minutes = integer()
%% Seconds = integer()
%% Retry = integer() | infinity
%% RetrySeconds = integer()
%% MFA = {Module, Function, Args}
%% @doc Schedules the MFA at the given Date and Time and retry if it fails.
%%
%%      Same description of insert/2. Additionally if MFA returns
%%      `{error, Reason}'  ecron will retry to execute
%%      it after `RetrySeconds'. The MFA will be rescheduled for a
%%      maximum of Retry times. If MFA returns `{apply, fun()}' and the
%%      return value of `fun()' is `{error, Reason}' the
%%      retry mechanism applies to `fun'. If Retry is equal to 3
%%      then MFA will be executed for a maximum of four times. The first time
%%      when is supposed to run according to the schedule and then three more
%%      times at interval of RetrySeconds.
%% @end
%%------------------------------------------------------------------------------
insert({Date, Time} = _DateTime, MFA, Retry, Seconds) ->
    case validate(Date, Time) of
        ok ->
            DueSec = sec({Date, Time}),
            DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
            Key = {DueSec, mnesia:dirty_update_counter(?JOB_COUNTER, job,1)},
            Job = #job{key = Key,
                       mfa = {MFA, DueTime},
                       schedule = {Date, Time},
                       retry = {Retry, Seconds}},
            gen_server:cast(?MODULE, {insert, Job});
        Error ->
            Error
    end.


%% @spec list() -> JobList
%% @doc Returns a list of job records defined in ecron.hrl
%% @end
%%------------------------------------------------------------------------------
list() ->
    gen_server:call(?MODULE, list, 60000).

%%------------------------------------------------------------------------------
%% @spec print_list() -> ok
%% @doc Prints a pretty list of records sorted by Job ID. <br/>
%% E.g. <br/>
%% <pre>
%% -----------------------------------------------------------------------
%% ID: 208
%% Function To Execute: mfa
%% Next Execution DateTime: {{2009,11,8},{15,59,54}}
%% Scheduled Execution DateTime: {{2009,11,8},{15,59,34}}
%% MFA: {ecron_tests,test_function,[fra]}
%% Schedule: {{'*','*',8},{15,59,34}}
%% Max Retry Times: 4
%% Retry Interval: 20
%% -----------------------------------------------------------------------
%% </pre>
%% <b>`ID'</b> is the Job ID and should be used as argument in
%% `delete/1'.<br/>
%% <b>`Function To Execute'</b> says if the job refers to the
%% MFA or the `fun' returned by MFA.
%%
%% <b>`Next Execution DateTime'</b> is the date and time when
%% the job will be executed.
%%
%% <b>`Scheduled Execution DateTime'</b> is the date and time
%% when the job was supposed to be executed according to the given
%% `Schedule'.`Next Execution DateTime' and
%% `Scheduled Execution DateTime' are different if the MFA, or
%% the `fun', failed and it will be retried later
%% (as in the example given above).
%%
%% <b>`MFA'</b> is a tuple with Module, Function and Arguments as
%% given when the job was inserted.<br/>
%% <b>`Schedule'</b> is the schedule for the MFA as given when the
%% job was insterted.<br/>
%% <b>`Max Retry Times'</b> is the number of times ecron will retry to
%% execute the job in case of failure. It may be less than the value given
%% when the job was inserted if a failure and a retry has already occured.
%%
%% <b>`Retry Interval'</b> is the number of seconds ecron will wait
%% after a failure before retrying to execute the job. It's the value given
%% when the job was inserted.
%% @end
%%------------------------------------------------------------------------------
print_list() ->
    Jobs = gen_server:call(?MODULE, list, 60000),
    SortedJobs = lists:usort(
                   fun(J1, J2) ->
                           element(2, J1#job.key) =< element(2, J2#job.key)
                   end,
                   Jobs),
    lists:foreach(
      fun(Job) ->
              #job{key = {ExecSec, Id},
                   schedule = Schedule,
                   mfa = {MFA, DueDateTime},
                   retry = {RetryTimes, Seconds},
                   client_fun = Fun
                  } = Job,
              {Function, ExpectedDateTime} =
                  case Fun of
                      undefined -> {mfa, DueDateTime};
                      {_, DT}   -> {'fun', DT}
                  end,
              ExecDateTime = calendar:gregorian_seconds_to_datetime(ExecSec),
              io:format("~70c-~n",[$-]),
              io:format("ID: ~p~nFunction To Execute: ~p~n"
			"Next Execution DateTime: ~p~n",
                           [Id, Function, ExecDateTime]),
              io:format("Scheduled Execution DateTime: ~w~nMFA: ~w~n"
			"Schedule: ~p~n",
                        [ExpectedDateTime, MFA, Schedule]),
              io:format("Max Retry Times: ~p~nRetry Interval: ~p~n",
			[RetryTimes, Seconds]),
              io:format("~70c-~n",[$-])
      end, SortedJobs).

%%------------------------------------------------------------------------------
%% @spec refresh() -> ok
%% @doc Deletes all jobs and recreates the table from the environment variables.
%% @end
%%------------------------------------------------------------------------------
refresh() ->
    gen_server:cast(?MODULE, refresh).

%%------------------------------------------------------------------------------
%% @spec execute_all() -> ok
%% @doc Executes all cron jobs in the queue, irrespective of the time they are
%% scheduled to run. This might be used at startup and shutdown, ensuring no
%% data is lost and backedup data is handled correctly. <br/>
%% It asynchronously returns `ok' and then executes all the jobs
%% in parallel. <br/>
%% No retry will be executed even if the MFA, or the `fun', fails
%% mechanism is enabled for that job. Also in case of periodic jobs MFA won't
%% be rescheduled. Thus the jobs list will always be empty after calling
%% `execute_all/0'.
%% @end
%%------------------------------------------------------------------------------
execute_all() ->
    gen_server:cast(?MODULE, execute_all).

%%------------------------------------------------------------------------------
%% @spec delete(ID) -> ok
%% @doc Deletes a cron job from the list.
%% If the job does not exist, the function still returns ok
%% @see print_list/0
%% @end
%%------------------------------------------------------------------------------
delete(ID) ->
    gen_server:cast(?MODULE, {delete, ID}).

%%------------------------------------------------------------------------------
%% @spec delete_all() -> ok
%% @doc Delete all the scheduled jobs
%% @end
%%------------------------------------------------------------------------------
delete_all() ->
    gen_server:cast(?MODULE, delete).

%%==============================================================================
%% gen_server callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @spec init(Args) -> {ok, State}
%% @doc
%% @private
%% @end
%%------------------------------------------------------------------------------
init(_Args) ->
    NewScheduled =
        case application:get_env(ecron, scheduled) of
            undefined     -> [];
            {ok, MFAList} -> MFAList
        end,
    OldScheduled = mnesia:activity(async_dirty,
        fun() ->
                Objs = mnesia:select(?JOB_TABLE,
                                 [{#job{_ = '_'},
                                   [], ['$_']}]),
                {atomic, ok} = mnesia:clear_table(?JOB_TABLE),
                Objs
        end),
    Scheduled = remove_duplicated(NewScheduled, OldScheduled, OldScheduled),
    lists:foreach(fun create_add_job/1, Scheduled),
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {ok, [], get_timeout(DueSec)};
        '$end_of_table' ->
            {ok, []}
    end.
%%------------------------------------------------------------------------------
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                    {noreply, State, Timeout} |
%%                                    {stop, Reason, State}
%% @doc Handling all non call/cast messages
%% @private
%% @end
%%------------------------------------------------------------------------------
handle_info(timeout, State) ->
    case mnesia:dirty_first(?JOB_TABLE) of
        '$end_of_table' ->
            {noreply, State};
        K ->
            check_job(K, State)
    end;

handle_info(_, State) ->
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {reply, ok, State, get_timeout(DueSec)};
        '$end_of_table' ->
            {reply, ok, State}
    end.

%%------------------------------------------------------------------------------
%% @spec handle_call(Request, From, State) -> {reply, Reply, State, Timeout}|
%%                                            {reply, Reply, State}
%% @doc Handling call messages
%% @private
%% @end
%%------------------------------------------------------------------------------
handle_call(list, _From, State) ->
    Keys = mnesia:dirty_all_keys(?JOB_TABLE),
    Jobs = lists:map(fun(Key) ->
                     [J] =  mnesia:dirty_read(?JOB_TABLE, Key),
                      J
                     end, Keys),
    case Keys of
        [] ->
            {reply, Jobs, State};
        Keys ->
            {DueSec, _} = hd(Keys),
            {reply, Jobs, State, get_timeout(DueSec)}
    end.

%%------------------------------------------------------------------------------
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @doc Handling cast messages
%% @private
%% @end
%%------------------------------------------------------------------------------
handle_cast({insert, Job}, State) ->
    ok = mnesia:dirty_write(Job),
    {DueSec, _} = mnesia:dirty_first(?JOB_TABLE),
    {noreply, State, get_timeout(DueSec)};

handle_cast({delete, {_, _} = Key}, State) ->
    ok = mnesia:dirty_delete(?JOB_TABLE, Key),
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {noreply, State, get_timeout(DueSec)};
        '$end_of_table' ->
            {noreply, State}
    end;

handle_cast({delete, ID}, State) ->
    ok = mnesia:activity(async_dirty,
        fun() ->
                case mnesia:select(?JOB_TABLE,
                                   [{#job{key = {'_', ID}, _='_'},
                                     [], ['$_']}]) of
                    [] ->
                        ok;
                    [Obj] ->
                        ok = mnesia:delete_object(Obj)
                end
        end),
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {noreply, State, get_timeout(DueSec)};
        '$end_of_table' ->
            {noreply, State}
    end;

handle_cast(delete, State) ->
    {atomic, ok} = mnesia:clear_table(?JOB_TABLE),
    {noreply, State};

handle_cast(execute_all, State) ->
    Scheduled = mnesia:activity(async_dirty,
        fun() ->
                Objs = mnesia:select(?JOB_TABLE,
                                 [{#job{_ = '_'},
                                   [], ['$_']}]),
                {atomic, ok} = mnesia:clear_table(?JOB_TABLE),
                Objs
        end),
    lists:foreach(fun(Job) ->
                          NoRetryJob = Job#job{retry={undefined, undefined}},
                          spawn(?MODULE, execute_job, [NoRetryJob, false])
                  end, Scheduled),
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {noreply, State, get_timeout(DueSec)};
        '$end_of_table' ->
            {noreply, State}
    end;

handle_cast(refresh, State) ->
    {atomic, ok} = mnesia:clear_table(?JOB_TABLE),
    NewScheduled =
        case application:get_env(ecron, scheduled) of
            undefined     -> [];
            {ok, MFAList} -> MFAList
        end,
    lists:foreach(fun create_add_job/1, NewScheduled),
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {noreply, State, get_timeout(DueSec)};
        '$end_of_table' ->
            {noreply, State}
    end;

handle_cast(stop, State) ->
	{stop, normal, State};
handle_cast(_Msg, State) ->
	{noreply, State}.

%%------------------------------------------------------------------------------
%% @spec terminate(Reason, State) -> void()
%%      Reason = term()
%%      State = term()
%% @doc This function is called by a gen_server when it is about to
%%      terminate. It should be the opposite of Module:init/1 and do
%%      any necessary cleaning up. When it returns, the gen_server
%%      terminates with Reason.  The return value is ignored.
%% @private
%% @end
%%------------------------------------------------------------------------------
terminate(_Reason, _State) ->
	ok.

%%------------------------------------------------------------------------------
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed
%% @private
%% @end
%%------------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    case mnesia:dirty_first(?JOB_TABLE) of
        {DueSec, _} ->
            {ok, State, get_timeout(DueSec)};
        '$end_of_table' ->
            {ok, State}
    end.



%%==============================================================================
%% Internal functions
%%==============================================================================
sec() ->
    calendar:datetime_to_gregorian_seconds(ecron_time:localtime()).
sec({'*', Time}) ->
    sec({{'*','*','*'}, Time});

sec({{'*','*','*'}, Time}) ->
    {Date1, Time1} = ecron_time:localtime(),
    Now = calendar:datetime_to_gregorian_seconds({Date1, Time1}),
    Due = calendar:datetime_to_gregorian_seconds({Date1, Time}),
    case Due - Now of
        Diff when Diff =<0 ->
            %% The Job will be executed tomorrow at Time
            Due + 86400;
        _Diff ->
            Due
    end;


sec({{'*','*',Day}, Time}) ->
    {{Year1, Month1, Day1}, Time1} = ecron_time:localtime(),
    Now = calendar:datetime_to_gregorian_seconds({{Year1, Month1, Day1}, Time1}),
    RealDay = get_real_day(Year1, Month1, Day),
    Due = calendar:datetime_to_gregorian_seconds({{Year1, Month1, RealDay}, Time}),
    case Due - Now of
        Diff when Diff =<0 ->
            %% The Job will be executed next month
            DueDate = add_month({Year1, Month1, Day}),
            calendar:datetime_to_gregorian_seconds({DueDate, Time});
        _Diff ->
            Due
    end;

sec({{'*', Month, Day}, Time}) ->
    {{Year1, Month1, Day1}, Time1} = ecron_time:localtime(),
    Now = calendar:datetime_to_gregorian_seconds({{Year1, Month1, Day1}, Time1}),
    RealDay = get_real_day(Year1, Month, Day),
    Due = calendar:datetime_to_gregorian_seconds({{Year1, Month, RealDay}, Time}),
    case Due - Now of
        Diff when Diff =<0 ->
            %% The Job will be executed next year
            calendar:datetime_to_gregorian_seconds({{Year1+1, Month, Day}, Time});
        _Diff ->
            Due
    end;

sec({{Year, Month, Day}, Time}) ->
    RealDay = get_real_day(Year, Month, Day),
    calendar:datetime_to_gregorian_seconds({{Year, Month, RealDay}, Time}).

add_month({Y, M, D}) ->
    case M of
        12 -> {Y+1, 1, get_real_day(Y+1, 1, D)};
        M  -> {Y, M+1, get_real_day(Y, M+1, D)}
    end.

get_real_day(Year, Month, last) ->
    calendar:last_day_of_the_month(Year, Month);

get_real_day(_, _, Day) ->
    Day.

%%------------------------------------------------------------------------------
%% @spec check_job(Key, State) -> {noreply, State} | {noreply, State, Timeout}
%% @doc Checks if there's a job to execute in the table, extracts it and runs it
%% @private
%% @end
%%------------------------------------------------------------------------------
check_job({Due, _} = K, State)->
    case Due - sec() of
        Diff when Diff =< 0 ->
            [Job] = mnesia:dirty_read(?JOB_TABLE, K),
            ok = mnesia:dirty_delete(?JOB_TABLE, K),
            NeedReschedule = is_not_retried(Job),
            spawn(?MODULE, execute_job, [Job, NeedReschedule]),
            case mnesia:dirty_first(?JOB_TABLE) of
                '$end_of_table' ->
                    {noreply, State};
                K1->
                    check_job(K1, State)
            end;
        _Diff ->
            {noreply, State, get_timeout(Due)}
    end.

%%------------------------------------------------------------------------------
%% @spec execute_job(Job, Reschedule) -> ok
%% @doc Used internally. Execute the given Job. Reschedule it in case of a
%%      periodic job, or in case the date is in the future.
%% @private
%% @end
%%------------------------------------------------------------------------------
execute_job(#job{client_fun = undefined, mfa = {{M, F, A}, DueTime},
                 retry = {RetryTimes, Interval}, schedule = Schedule},
	    Reschedule) ->
    ExecutionTime = ecron_time:localtime(),
    try apply(M, F, A) of
        {apply, Fun} when is_function(Fun, 0) ->
            notify({mfa_result, {apply, Fun}, {Schedule, {M, F, A}},
		    DueTime, ExecutionTime}),
            execute_fun(
	      Fun, Schedule,{M, F, A}, DueTime, {RetryTimes, Interval});
        ok ->
            notify({mfa_result, ok, {Schedule, {M, F, A}},
		    DueTime, ExecutionTime});
        {ok, Data} ->
            notify({mfa_result, {ok, Data}, {Schedule, {M, F, A}},
		    DueTime, ExecutionTime});
        {error, Reason} ->
            notify({mfa_result, {error, Reason}, {Schedule, {M, F, A}},
		    DueTime, ExecutionTime}),
            retry(
	      {M, F, A}, undefined, Schedule, {RetryTimes, Interval}, DueTime);
        Return ->
            notify({mfa_result, Return, {Schedule, {M, F, A}}, DueTime,
		    ExecutionTime})
    catch
        _:Error ->
            notify(
	      {mfa_result, Error, {Schedule, {M, F, A}}, DueTime, ExecutionTime})
    end,
    case Reschedule of
        true  -> insert(Schedule, {M, F, A}, RetryTimes, Interval);
        false -> ok
    end;


execute_job(#job{client_fun = {Fun, DueTime},
		 mfa = {MFA, _},
		 schedule = Schedule,
                 retry = Retry}, _) ->
    execute_fun(Fun, Schedule, MFA, DueTime, Retry).

%%------------------------------------------------------------------------------
%% @spec execute_fun(Fun, Schedule, MFA, Time, Retry) -> ok
%% @doc Executes the `fun' returned by MFA
%% @private
%% @end
%%------------------------------------------------------------------------------
execute_fun(Fun, Schedule, MFA, DueTime, Retry) ->
    ExecutionTime = ecron_time:localtime(),
    try Fun() of
        ok ->
            notify({fun_result, ok, {Schedule, MFA}, DueTime, ExecutionTime}),
            ok;
        {ok, Data} ->
            notify({fun_result, {ok, Data}, {Schedule, MFA}, DueTime,
		    ExecutionTime}),
            ok;
        {error, Reason} ->
            notify({fun_result, {error, Reason}, {Schedule, MFA}, DueTime,
		    ExecutionTime}),
            retry(MFA, Fun, Schedule, Retry, DueTime);
        Error ->
            notify({fun_result, Error, {Schedule, MFA}, DueTime, ExecutionTime})
      catch
          _:Error ->
              notify({fun_result, Error, {Schedule, MFA}, DueTime,
		      ExecutionTime})
      end.

%%------------------------------------------------------------------------------
%% @spec retry(MFA, Fun, Schedule, Retry, Time) -> ok
%%      Retry = {RetryTimes, Seconds}
%%      RetryTimes = integer()
%%      Seconds = integer()
%% @doc Reschedules the job if Retry options are given.
%%      Fun, or MFA if Fun is undefined, will be executed after Seconds.
%%      If RetryTimes is zero it means the job has been re-scheduled too many
%%      times therefore it won't be inserted again. <br/>
%%      An event is sent when the job is rescheduled and in case max number
%%      of retry is reached.
%% @private
%% @end
%%------------------------------------------------------------------------------
retry(_MFA, _Fun, _Schedule, {undefined, undefined}, _) ->
    ok;
retry(MFA, Fun, Schedule, {0, _Seconds}, DueTime) ->
    notify({max_retry, {Schedule, MFA}, Fun, DueTime});
retry(MFA, Fun, Schedule, {RetryTime, Seconds}, DueTime) ->
    notify({retry, {Schedule, MFA}, Fun, DueTime}),
    Now = sec(),
    DueSec = Now + Seconds,
    Key = {DueSec, mnesia:dirty_update_counter({job_counter, job},1)},
    case Fun of
        undefined -> ClientFun = undefined;
        Fun       -> ClientFun = {Fun, DueTime}
    end,
    Job = #job{key = Key,
               mfa = {MFA, DueTime},
               schedule = Schedule,
               client_fun = ClientFun,
               retry = {RetryTime-1, Seconds}},
    gen_server:cast(?MODULE, {insert, Job}).

%%------------------------------------------------------------------------------
%% @spec create_add_job(Job) -> ok | error
%%  Job = {{Date, Time}, MFA}
%%  Job = {{Date, Time}, MFA, RetryTimes, Seconds}
%%  Job = #job{}
%% @doc Used internally
%% @private
%% @end
%%------------------------------------------------------------------------------
create_add_job({{Date, Time}, MFA}) ->
    create_add_job({{Date, Time}, MFA, undefined, undefined});

create_add_job({{Date, Time}, MFA, RetryTimes, Seconds}) ->
    case validate(Date, Time) of
        ok ->
            DueSec = sec({Date, Time}),
            DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
            Key = {DueSec, mnesia:dirty_update_counter({job_counter, job}, 1)},
            Job = #job{key = Key,
                       mfa = {MFA, DueTime},
                       schedule = {Date, Time},
                       retry = {RetryTimes, Seconds}},
            ok = mnesia:dirty_write(Job);
        Error ->
            Error
    end;

create_add_job(#job{client_fun = undefined, schedule = {Date, Time}} = Job) ->
    DueSec = sec({Date, Time}),
    Key = {DueSec, mnesia:dirty_update_counter({job_counter, job}, 1)},
    ok = mnesia:dirty_write(Job#job{key = Key});

%% This entry was related to a previously failed MFA execution
%% therefore it will retry after the configured retry_time
create_add_job(#job{retry = {_, Seconds}} = Job) ->
    DueSec = sec() + Seconds,
    Key = {DueSec, mnesia:dirty_update_counter({job_counter, job}, 1)},
    ok = mnesia:dirty_write(Job#job{key = Key}).

%%------------------------------------------------------------------------------
%% @spec notify(Event) -> ok
%%       Event = term()
%% @doc Sends the Event notification to all the configured event handlers
%% @private
%% @end
%%------------------------------------------------------------------------------
notify(Event) ->
    ok = gen_event:notify(?EVENT_MANAGER, Event).

validate('*', Time) ->
    validate({'*','*', '*'}, Time);

validate(Date, Time) ->
    case validate_date(Date) andalso
         validate_time(Time) of
        true ->
            Now = sec(),
            case catch sec({Date, Time}) of
                {'EXIT', _} ->
                    {error, date};
                Sec when Sec - Now >0 ->
                    ok;
                _  ->
                    {error, date}
            end;
        false ->
            {error, date}
    end.

validate_date({'*','*', '*'}) ->
    true;
validate_date({'*','*', last}) ->
    true;
validate_date({'*','*', Day}) when is_integer(Day), Day>0, Day<29 ->
    true;
validate_date({'*', 2, Day}) when is_integer(Day), Day>0, Day<29 ->
    true;
validate_date({'*', Month, last}) when is_integer(Month), Month>0, Month<13 ->
    true;
validate_date({'*', Month, Day}) when is_integer(Day), is_integer(Month),
                                      Month>0, Month<13, Day>0 ->
    ShortMonths = [4,6,9,11],
    case lists:member(Month, ShortMonths) of
        true  -> Day < 31;
        false -> Day < 32
    end;
validate_date({Y, M, last}) ->
    is_integer(Y) andalso is_integer(M)
        andalso M>0 andalso M<13;

validate_date(Date) ->
    try
        calendar:valid_date(Date)
    catch _:_ ->
            false
    end.

validate_time({H, M, S}) ->
    is_integer(H) andalso is_integer(M) andalso is_integer(S)
        andalso H>=0 andalso H=<23
        andalso M>=0 andalso M=<59
        andalso S>=0 andalso S=<59;
validate_time(_) ->
    false.


%% return a lists of {Schedule,MFA} or {Schedule, MFA, RetryTimes, RetrySeconds}
%% and #job{} where elements from the
%% ScheduledMFAList are removed if they are present in the jobList
remove_duplicated([], _, AccJobs) ->
    AccJobs;
remove_duplicated([{Schedule, MFA}|T], JobList, AccJobs) ->
    case lists:any(fun(J) ->
                           element(1,J#job.mfa)==MFA
			       andalso J#job.schedule == Schedule
			       andalso J#job.client_fun == undefined
                   end, JobList) of
        true ->
	    %% The MFA was already present in the table
	    remove_duplicated(T, JobList, AccJobs);
        false ->
	    remove_duplicated(T, JobList, [{Schedule, MFA}|AccJobs])
    end;
remove_duplicated([{Schedule, MFA, Retry, Sec}|T], JobList, AccJobs) ->
    case lists:any(fun(J) ->
                           element(1,J#job.mfa) == MFA
			       andalso J#job.schedule == Schedule
			       andalso J#job.client_fun == undefined
			       andalso J#job.schedule == {Retry, Sec}
                   end, JobList) of
        true ->
	    %% The MFA was already present in the table
	    remove_duplicated(T, JobList, AccJobs);
        false ->
	    remove_duplicated(T, JobList, [{Schedule, MFA, Retry, Sec}|AccJobs])
    end.

get_timeout(DueSec) ->
    case DueSec - sec() of
        Diff when Diff =< 0      -> 5;
        Diff when Diff > 2592000 ->
	    2592000000; %% Check the queue once every 30 days anyway
        Diff                     -> Diff*1000
    end.

create_table(Table, Opts) ->
    {atomic, ok} = mnesia:create_table(Table, Opts),
    ok.

%% Check whether it's the first attempt to execute a job and not a retried one
is_not_retried(#job{client_fun = undefined, key = {DueSec, _},
                mfa = {_, ExpectedDateTime}}) ->
    DueDateTime = calendar:gregorian_seconds_to_datetime(DueSec),
    DueDateTime == ExpectedDateTime;
is_not_retried(_) ->
    false.
