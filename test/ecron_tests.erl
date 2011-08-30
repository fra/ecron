-module(ecron_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("ecron/src/ecron.hrl").

-export([test_function/1,
         test_function1/1,
         test_not_ok_function/1,
         wrong_fun/1,
         wrong_mfa/1,
         ok_mfa/1,
         ok_mfa1/1,
         retry_mfa/1]).

general_test_() ->
    {inorder,
      {setup, fun start_app/0, fun stop_app/1,
        [
         ?_test(insert_validation()),
         ?_test(insert()),
         ?_test(insert1()),
         ?_test(insert2()),
         ?_test(insert3()),
         ?_test(insert_daily()),
         ?_test(insert_daily2()),
         ?_test(insert_daily3()),
         ?_test(insert_monthly()),
         ?_test(insert_yearly()),
         ?_test(insert_fun_not_ok()),
         {timeout, 10, ?_test(retry_mfa())},
         ?_test(insert_wrong_fun()),
         ?_test(insert_wrong_mfa()),
         ?_test(delete_not_existent()),
         ?_test(insert_last()),
         ?_test(insert_last1()),
         ?_test(insert_last2()),
         ?_test(load_from_app_file()),
         {timeout, 10, ?_test(load_from_file_and_table())},
         ?_test(refresh()),
         ?_test(execute_all()),
         ?_test(event_handler_api())
        ]}}.

start_app() ->
    ets:new(ecron_test, [named_table, public, duplicate_bag]),
    application:set_env(ecron, scheduled, []),
    mnesia:delete_schema([node()]),
    mnesia:create_schema([node()]),
    ok = application:start(mnesia),
    ok = ecron:install([node()]),
    ok = mnesia:wait_for_tables([?JOB_TABLE],10000),
    {atomic, ok} = mnesia:clear_table(?JOB_TABLE),
    ok = application:start(ecron),
    mock_datetime(),
    {ok, _} = ecron:add_event_handler(ecron_event_handler_test, []),
    ok = gen_event:delete_handler(?EVENT_MANAGER, ecron_event, []).

mock_datetime() ->
    meck:new(ecron_time),
    BaseNow = {1313, 678000, 769000},  % equiv. {{2011,8,18}, {16,33,20}}.
    Diff = t_localtime_setup(BaseNow),
    meck:expect(ecron_time, localtime, fun() -> t_localtime(Diff) end),
    meck:expect(ecron_time, universaltime,
		fun() -> t_localtime(Diff) end),
    meck:expect(ecron_time, now, fun() -> t_now(Diff) end),
    meck:expect(ecron_time, timestamp, fun() -> t_now(Diff) end).

t_localtime_setup(Now) ->
    RealNow = erlang:now(),
    DateTime = calendar:now_to_local_time(Now),
    RealDateTime = calendar:now_to_local_time(RealNow),
    Secs = calendar:datetime_to_gregorian_seconds(DateTime),
    RealSecs = calendar:datetime_to_gregorian_seconds(RealDateTime),
    {{Now, RealNow}, {DateTime, RealDateTime}, {Secs, RealSecs}}.

t_localtime({_, _, {Secs, RealSecs}}) ->
    Cur = erlang:localtime(),
    CurSecs = calendar:datetime_to_gregorian_seconds(Cur),
    Diff = CurSecs - RealSecs,
    calendar:gregorian_seconds_to_datetime(Secs + Diff).

t_now({{{MS1,S1,US1} = _Now, {MS2,S2,US2} = _RealNow}, _, _}) ->
    {MSc,Sc,USc} = erlang:now(),
    {MS1 + (MSc - MS2), S1 + (Sc - S2), US1 + (USc - US2)}.

stop_app(_) ->
    application:stop(ecron),
    application:stop(mnesia),
    ets:delete(ecron_test).

%% test ecron:insert/1 returns error when Date or Time are not correct
insert_validation() ->
    {{Y, _M, _D},Time} = ecron_time:localtime(),
    ?assertMatch({error, _}, ecron:insert({4,{12,5,50}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{Y, 13, 2}, {12,5,5}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{2009, 1, wrong}, {12,5,5}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{2009, 12, 2}, {wrong,5,5}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{2009, 12, 2}, {'*',5,5}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{2009, 7, 2}, 2},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', '*', 29}, Time},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', 2, 29}, Time},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', 5, '*'}, Time},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', 4, 31}, Time},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', '*', '*'}, {60,0,0}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', '*', '*'}, {56,60,0}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{'*', '*', '*'}, {56,45,60}},
					  {ecron_tests, test_function, [any]})),
    ?assertMatch({error, _}, ecron:insert({{Y-1, 7, 2}, Time},
					  {ecron_tests, test_function, [any]})).

%% test job are correctly inserted into the queue with the right scheduled time
%% Fixed Date
%% MFA returns {apply, fun()} fun returns ok
insert() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(DateTime,
				  {ecron_tests, test_function, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function,
			       [UniqueKey]},DateTime},
                       schedule = DateTime, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    ?assertEqual([], ecron:list()),
    ?assertMatch([{fun_result, ok,
		   {DateTime, {ecron_tests, test_function, [UniqueKey]}},
                   DateTime, DateTime},
                  {mfa_result, {apply, _},
		   {DateTime, {ecron_tests, test_function, [UniqueKey]}},
                   DateTime, DateTime}], ets:tab2list(event_test)),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% MFA returns {apply, fun()} fun returns {ok, Data}
insert1() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(DateTime,
				  {ecron_tests, test_function1, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function1, [UniqueKey]},
			      DateTime},
                       schedule = DateTime, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    ?assertEqual([], ecron:list()),
    ?assertMatch([{fun_result, {ok, UniqueKey},
		   {DateTime, {ecron_tests, test_function1, [UniqueKey]}},
                   DateTime, DateTime},
                  {mfa_result, {apply, _},
		   {DateTime, {ecron_tests, test_function1, [UniqueKey]}},
                   DateTime, DateTime}], ets:tab2list(event_test)),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% MFA returns ok
insert2() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(DateTime,{ecron_tests, ok_mfa, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, ok_mfa, [UniqueKey]},DateTime},
                       schedule = DateTime, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    ?assertMatch([{mfa_result, ok,
		   {DateTime, {ecron_tests, ok_mfa, [UniqueKey]}},
                   DateTime, DateTime}], ets:tab2list(event_test)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% MFA returns {ok, Data}
insert3() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(DateTime,{ecron_tests, ok_mfa1, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, ok_mfa1, [UniqueKey]},DateTime},
                       schedule = DateTime, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    ?assertMatch([{mfa_result, {ok, UniqueKey},
		   {DateTime, {ecron_tests, ok_mfa1, [UniqueKey]}},
                   DateTime, DateTime}], ets:tab2list(event_test)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% Insert daily job, first execution in 2 seconds
%% it also tests ecron:delete(Key)
%% {{'*','*','*'}, Time}
insert_daily() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    {{Y,M,D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({{'*', '*', '*'}, Time},
				  {ecron_tests, test_function, [UniqueKey]})),
    timer:sleep(300),
    ?assertMatch({Schedule, _}, mnesia:dirty_first(?JOB_TABLE)),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey]},
			      {{Y,M,D}, Time}},
                       schedule = {{'*', '*', '*'}, Time},
		       client_fun = undefined,
                       retry = {undefined, undefined}}], 
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    DueSec = Schedule+3600*24,
    DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
    [Job] = ecron:list(),
    ?assertMatch(#job{mfa = {{ecron_tests,test_function,[UniqueKey]},DueTime},
		      key = {DueSec, _},
                      schedule = {{'*', '*', '*'}, Time}, client_fun = undefined,
                      retry = {undefined, undefined}}, Job),
    ?assertEqual(ok, ecron:delete(Job#job.key)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% {'*', Time} and retry options
insert_daily2() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    {{Y,M,D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({'*', Time},
				  {ecron_tests, test_function, [UniqueKey]},
				  3, 1)),
    timer:sleep(300),
    ?assertMatch({Schedule, _}, mnesia:dirty_first(?JOB_TABLE)),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey]},
			      {{Y,M,D}, Time}},
                       schedule = {'*', Time},
		       client_fun = undefined, retry = {3, 1}}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    DueSec = Schedule+3600*24,
    DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
    [Job] = ecron:list(),
    ?assertMatch(#job{mfa = {{ecron_tests, test_function, [UniqueKey]},
			     DueTime},
		      key = {DueSec, _},
		      schedule = {'*', Time},
		      client_fun = undefined,
		      retry = {3, 1}}, Job),
    ?assertEqual(ok, ecron:delete(Job#job.key)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% {'*', Time}, MFA returns {error, Reason}
insert_daily3() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    {{Y,M,D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({'*', Time},
				  {ecron_tests, retry_mfa, [UniqueKey]}, 3, 1)),
    timer:sleep(300),
    ?assertMatch({Schedule, _}, mnesia:dirty_first(?JOB_TABLE)),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, retry_mfa, [UniqueKey]},
			      {{Y,M,D}, Time}},
                       schedule = {'*', Time},
		       client_fun = undefined,
		       retry = {3, 1}}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    DueSec = Schedule+3600*24,
    DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
    RetryDueSec = Schedule+1,
    [Job, Job1] = ecron:list(),
    ?assertMatch(#job{mfa = {{ecron_tests, retry_mfa, [UniqueKey]}, DueTime},
		      key = {DueSec, _},
		      schedule = {'*', Time},
		      client_fun = undefined,
		      retry = {3, 1}}, Job1),
    ?assertMatch(#job{mfa = {{ecron_tests, retry_mfa, [UniqueKey]},
			     {{Y,M,D}, Time}},
                      key = {RetryDueSec, _}, schedule = {'*', Time},
                      client_fun = undefined, retry = {2, 1}}, Job),
    ?assertEqual(ok, ecron:delete(element(2, Job#job.key))),
    ?assertEqual(ok, ecron:delete(element(2, Job1#job.key))),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% Insert monthly job, first execution in 2 seconds
%% it also tests ecron:delete(Key)
insert_monthly() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    {{Y, M, D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({{'*', '*', D}, Time},
				  {ecron_tests, test_function, [UniqueKey]})),
    timer:sleep(300),
    ?assertMatch({Schedule, _}, mnesia:dirty_first(?JOB_TABLE)),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey]},
			      {{Y, M, D}, Time}},
                       schedule = {{'*', '*', D}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    DueSec = calendar:datetime_to_gregorian_seconds(
	       {add_month({Y, M, D}), Time}),
    DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
    [Job] = ecron:list(),
%    ?debugFmt("UniqueKey~p DueSec=~p Time=~p~n",[UniqueKey, DueSec, Time]),
    ?assertMatch(#job{mfa = {{ecron_tests, test_function, [UniqueKey]}, DueTime},
		      key = {DueSec, _},
		      schedule = {{'*', '*', D}, Time},
		      client_fun = undefined}, Job),
    ?assertEqual(ok, ecron:delete(Job#job.key)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% Insert yearly job, first execution in 2 seconds
%% it also tests ecron:delete(JobId)
insert_yearly() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    {{Y, M, D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({{'*', M, D}, Time},
				  {ecron_tests, test_function, [UniqueKey]})),
    timer:sleep(300),
    ?assertMatch({Schedule, _}, mnesia:dirty_first(?JOB_TABLE)),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey]},
			      {{Y, M, D}, Time}},
                       schedule = {{'*', M, D}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    DueSec = calendar:datetime_to_gregorian_seconds({{Y+1, M, D}, Time}),
    DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
    [Job] = ecron:list(),
    ?assertMatch(#job{mfa = {{ecron_tests, test_function, [UniqueKey]},DueTime},
		      key = {DueSec, _},
		      schedule = {{'*', M, D}, Time},
		      client_fun = undefined}, Job),
    ?assertEqual(ok, ecron:delete(element(2, Job#job.key))),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% retry MFA 3 times
retry_mfa() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(DateTime,
				  {ecron_tests, retry_mfa, [UniqueKey]}, 3, 1)),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, retry_mfa, [UniqueKey]},DateTime},
                       schedule = DateTime,
		       client_fun = undefined, retry = {3,1}}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),

    timer:sleep(2100),
    DueSec = Schedule+1,
    [Job] = ecron:list(),
    ?assertMatch(#job{mfa = {{ecron_tests, retry_mfa, [UniqueKey]},DateTime},
		      key = {DueSec, _},
                      schedule = DateTime, client_fun = _, retry = {2,1}}, Job),
    DueSec1 = Schedule+2,
    ExecTime1 = calendar:gregorian_seconds_to_datetime(DueSec),
    DueSec2 = Schedule+3,
    ExecTime2 = calendar:gregorian_seconds_to_datetime(DueSec1),
    timer:sleep(3100),
    ?assertEqual([{UniqueKey, Schedule},
		  {UniqueKey, Schedule+1},
		  {UniqueKey, Schedule+2},
                  {UniqueKey, Schedule+3}],
		 ets:tab2list(ecron_test)),
    ExecTime3 = calendar:gregorian_seconds_to_datetime(DueSec2),
    Events = ets:tab2list(event_test),
    ?assertMatch([{max_retry,
		   {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
		   undefined, DateTime},
                  {mfa_result, {error, retry},
		   {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
                   DateTime, DateTime},
                  {mfa_result, {error, retry},
		   {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
                   DateTime, ExecTime1},
                  {mfa_result, {error, retry},
		   {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
                   DateTime, ExecTime2},
                  {mfa_result, {error, retry},
		   {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
                   DateTime, ExecTime3},
                  {retry, {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
		   undefined, DateTime},
                  {retry, {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
		   undefined, DateTime},
                  {retry, {DateTime, {ecron_tests, retry_mfa, [UniqueKey]}},
		   undefined, DateTime}
                 ],
                 lists:keysort(1,Events)),
    ets:delete_all_objects(event_test),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test).

%% Insert job to be scheduled on the last day of the current month
insert_last() ->
    TmpSchedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    {{Y,M,_}, Time} = calendar:gregorian_seconds_to_datetime(TmpSchedule),
    LastDay = calendar:last_day_of_the_month(Y, M),
    Schedule = calendar:datetime_to_gregorian_seconds({{Y, M, LastDay}, Time}),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({{Y, M, last}, Time},{ecron_tests, ok_mfa, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, ok_mfa, [UniqueKey]},
			      {{Y, M, LastDay}, Time}},
                       schedule = {{Y, M, last}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    ?assertEqual(1, length(ecron:list())),
    ?assertEqual(ok, ecron:delete_all()),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% Insert yearly job to be scheduled on the last day of the current month
insert_last1() ->
    TmpSchedule = calendar:datetime_to_gregorian_seconds(
		    ecron_time:localtime())+2,
    {{Y,M,_}, Time} = calendar:gregorian_seconds_to_datetime(TmpSchedule),
    LastDay = calendar:last_day_of_the_month(Y, M),
    Schedule = calendar:datetime_to_gregorian_seconds({{Y, M, LastDay}, Time}),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({{'*', M, last}, Time},
				  {ecron_tests, ok_mfa, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, ok_mfa, [UniqueKey]},
			      {{Y, M, LastDay}, Time}},
                       schedule = {{'*', M, last}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    ?assertEqual(1, length(ecron:list())),
    ?assertEqual(ok, ecron:delete_all()),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% Insert monthly job to be scheduled on the last day of a month
insert_last2() ->
    TmpSchedule = calendar:datetime_to_gregorian_seconds(
		    ecron_time:localtime())+2,
    {{Y,M,_}, Time} = calendar:gregorian_seconds_to_datetime(TmpSchedule),
    LastDay = calendar:last_day_of_the_month(Y, M),
    Schedule = calendar:datetime_to_gregorian_seconds({{Y, M, LastDay}, Time}),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert({{'*', '*', last}, Time},
				  {ecron_tests, ok_mfa, [UniqueKey]})),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, ok_mfa, [UniqueKey]},
			      {{Y, M, LastDay}, Time}},
                       schedule = {{'*', '*', last}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    ?assertEqual(1, length(ecron:list())),
    ?assertEqual(ok, ecron:delete_all()),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).


%% test the fun returned by MFA is rescheduled if it doesn't return ok.
%% It checks that the time in test_not_ok_function is the one related
%% to the scheduled time not the retry time to make sure it executes
%% the fun returned by MFA and not the MFA itself
insert_fun_not_ok() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(
		       DateTime, {ecron_tests,test_not_ok_function,[UniqueKey]},
		       5, 1)),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests,test_not_ok_function,[UniqueKey]},
			      DateTime},
                       schedule = DateTime,
		       client_fun = undefined,
		       retry = {5,1}}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2100),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    DueSec = Schedule+1,
    [Job] = ecron:list(),
    ?assertMatch(#job{mfa = {{ecron_tests,test_not_ok_function,[UniqueKey]},
			     DateTime}, key = {DueSec, _},
                      schedule = DateTime,
		      client_fun = _,
		      retry = {4,1}}, Job),
    Events = ets:tab2list(event_test),
    ?assertMatch([{retry,
		   {DateTime, {ecron_tests,test_not_ok_function,[UniqueKey]}},
		   _, DateTime},
                  {fun_result, {error, retry},
		   {DateTime, {ecron_tests, test_not_ok_function, [UniqueKey]}},
                   DateTime, DateTime},
                  {mfa_result, {apply, _},
		   {DateTime, {ecron_tests, test_not_ok_function, [UniqueKey]}},
                   DateTime, DateTime}], Events),
    [RetryEvent|_] = Events,
    ?assert(element(3, RetryEvent) /= undefined),
    ets:delete_all_objects(ecron_test),
    timer:sleep(1100),
    [Job1] = ecron:list(),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    ?assertEqual(ok, ecron:delete(Job1#job.key)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% test that MFA is executed at the given time and no retry is executed
%% since it doesn't return {error, Reason}
insert_wrong_mfa() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(
		       DateTime,{ecron_tests, wrong_mfa, [UniqueKey]}, 3, 1)),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, wrong_mfa, [UniqueKey]}, DateTime},
                       schedule = DateTime, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    ?assertMatch([{mfa_result, wrong,
		   {DateTime, {ecron_tests, wrong_mfa, [UniqueKey]}},
                   DateTime, DateTime}], ets:tab2list(event_test)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% test that fun is executed at the given time and no retry is executed
%% since it doesn't return {error, Reason}
insert_wrong_fun() ->
    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(
		       DateTime,{ecron_tests, wrong_fun, [UniqueKey]}, 3, 1)),
    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, wrong_fun, [UniqueKey]}, DateTime},
                       schedule = DateTime, client_fun = _}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    ?assertMatch([{fun_result, wrong,
		   {DateTime, {ecron_tests, wrong_fun, [UniqueKey]}},
                   DateTime, DateTime},
                  {mfa_result, {apply, _},
		   {DateTime, {ecron_tests, wrong_fun, [UniqueKey]}},
                   DateTime, DateTime}], ets:tab2list(event_test)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

load_from_app_file() ->
    application:stop(ecron),

    Schedule = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+2,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    Schedule1 = calendar:datetime_to_gregorian_seconds(ecron_time:localtime())+3,
    {{Y,M,D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule1),
    {A1,B1,C1} = now(),
    UniqueKey1 = lists:concat([A1, "-", B1, "-", C1]),
    application:set_env(ecron, scheduled,
			[{DateTime,{ecron_tests, test_function, [UniqueKey]}},
			 {{{'*', '*', '*'}, Time},
			  {ecron_tests, test_function, [UniqueKey1]}}]),
    timer:sleep(1000),
    application:start(ecron),
    {ok, _} = ecron:add_event_handler(ecron_event_handler_test, []),
    ok = gen_event:delete_handler(?EVENT_MANAGER, ecron_event, []),

    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function,
			       [UniqueKey]}, DateTime},
                       schedule = DateTime, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    JobKey1 = mnesia:dirty_next(?JOB_TABLE, JobKey),
    ?assertMatch({Schedule1, _}, JobKey1),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function,
			       [UniqueKey1]}, {{Y,M,D}, Time}},
                       schedule = {{'*', '*', '*'}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey1)),
    timer:sleep(2500),
    ?assertEqual([{UniqueKey, test}], ets:lookup(ecron_test, UniqueKey)),
    ?assertEqual([{UniqueKey1, test}], ets:lookup(ecron_test, UniqueKey1)),
    [Job1] = ecron:list(),
    DueSec = Schedule1+3600*24,
    DueTime = calendar:gregorian_seconds_to_datetime(DueSec),
    ?assertMatch(#job{mfa = {{ecron_tests, test_function,
			      [UniqueKey1]},DueTime}, key = {DueSec, _},
                      schedule = {{'*', '*', '*'}, Time},
		      client_fun = undefined}, Job1),
    ?assertEqual(ok, ecron:delete(Job1#job.key)),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

%% Restarts the application, verify that the previously scheduled jobs are
%% preserved and new ones are added into the queue from the environment variable
%% Also a daily job was present both in the table and in the file, test we
%% don't have a duplicated entry for it
load_from_file_and_table() ->
    LT = ecron_time:localtime(),
    Schedule = calendar:datetime_to_gregorian_seconds(LT)+1,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(
		       DateTime,
		       {ecron_tests, test_not_ok_function, [UniqueKey]},3,6)),
    Schedule1 = calendar:datetime_to_gregorian_seconds(LT)+6,
    {{Y,M,D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule1),
    {A1,B1,C1} = now(),
    UniqueKey1 = lists:concat([A1, "-", B1, "-", C1]),
    ?assertEqual(ok, ecron:insert({{'*', '*', '*'}, Time},
				  {ecron_tests, test_function, [UniqueKey1]})),
    timer:sleep(1300),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    ets:delete_all_objects(ecron_test),
    application:stop(ecron),

    Schedule2 = calendar:datetime_to_gregorian_seconds(LT)+5,
    DateTime2 = calendar:gregorian_seconds_to_datetime(Schedule2),
    {A2,B2,C2} = now(),
    UniqueKey2 = lists:concat([A2, "-", B2, "-", C2]),
    Schedule3 = calendar:datetime_to_gregorian_seconds(LT)+4,
    {{_Y,_M,_D}, Time3} = calendar:gregorian_seconds_to_datetime(Schedule3),
    {A3,B3,C3} = now(),
    UniqueKey3 = lists:concat([A3, "-", B3, "-", C3]),
%    ?debugFmt("DateTime=~pDateTime2=~pTime=~pTime3=~p~n",[DateTime, DateTime2, Time, Time3]),
    application:set_env(ecron, scheduled,
			[{DateTime2,{ecron_tests, test_function, [UniqueKey2]}},
			 {{{'*', '*', '*'}, Time3},
			  {ecron_tests, test_function, [UniqueKey3]}},
			 {{{'*', '*', '*'}, Time},
			  {ecron_tests, test_function, [UniqueKey1]}}]),
    timer:sleep(1000),
    application:start(ecron),
    {ok, _} = ecron:add_event_handler(ecron_event_handler_test, []),
    ok = gen_event:delete_handler(?EVENT_MANAGER, ecron_event, []),

    timer:sleep(300),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule3, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function,
			       [UniqueKey3]}, {{Y,M,D}, Time3}},
                       schedule = {{'*', '*', '*'}, Time3},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    JobKey1 = mnesia:dirty_next(?JOB_TABLE, JobKey),
    ?assertMatch({Schedule2, _}, JobKey1),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey2]},
			      DateTime2},
                       schedule = DateTime2, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey1)),
    JobKey2 = mnesia:dirty_next(?JOB_TABLE, JobKey1),
    ?assertMatch({Schedule1, _}, JobKey2),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey1]},
			      {{Y,M,D}, Time}},
                       schedule = {{'*', '*', '*'}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey2)),
    JobKey3 = mnesia:dirty_next(?JOB_TABLE, JobKey2),
    ?assertMatch([#job{mfa = {{ecron_tests, test_not_ok_function,
			       [UniqueKey]}, DateTime},
                       schedule = DateTime, client_fun = _}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey3)),
    ?assertEqual('$end_of_table', mnesia:dirty_next(?JOB_TABLE, JobKey3)),
    timer:sleep(6300),
    ?assertEqual([{UniqueKey, Schedule}], ets:lookup(ecron_test, UniqueKey)),
    ?assertEqual([{UniqueKey1, test}], ets:lookup(ecron_test, UniqueKey1)),
    ?assertEqual([{UniqueKey2, test}], ets:lookup(ecron_test, UniqueKey2)),
    ?assertEqual([{UniqueKey3, test}], ets:lookup(ecron_test, UniqueKey3)),
    ?assertEqual(3, length(ecron:list())),
    ?assertEqual(ok, ecron:delete_all()),
    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

delete_not_existent() ->
    ?assertEqual(ok, ecron:delete(fakekey)).


refresh() ->
    LT = ecron_time:localtime(),
    Schedule = calendar:datetime_to_gregorian_seconds(LT)+3,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(
		       DateTime,
		       {ecron_tests, test_not_ok_function, [UniqueKey]})),
    Schedule1 = calendar:datetime_to_gregorian_seconds(LT)+6,
    {{_Y,_M,_D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule1),
    {A1,B1,C1} = now(),
    UniqueKey1 = lists:concat([A1, "-", B1, "-", C1]),
    ?assertEqual(ok, ecron:insert(
		       {{'*', '*', '*'}, Time},
		       {ecron_tests, test_function, [UniqueKey1]})),
    ?assertEqual(2, length(ecron:list())),

    Schedule2 = calendar:datetime_to_gregorian_seconds(LT)+5,
    DateTime2 = calendar:gregorian_seconds_to_datetime(Schedule2),
    {A2,B2,C2} = now(),
    UniqueKey2 = lists:concat([A2, "-", B2, "-", C2]),
    Schedule3 = calendar:datetime_to_gregorian_seconds(LT)+4,
    {{Y,M,D}, Time3} = calendar:gregorian_seconds_to_datetime(Schedule3),
    {A3,B3,C3} = now(),
    UniqueKey3 = lists:concat([A3, "-", B3, "-", C3]),
    application:set_env(
      ecron,
      scheduled,
      [{DateTime2,{ecron_tests, test_function, [UniqueKey2]}},
       {{{'*', '*', '*'}, Time3},{ecron_tests, test_function, [UniqueKey3]}},
       {{{'*', '*', '*'}, Time},{ecron_tests, test_function, [UniqueKey1]}}]),

    ?assertEqual(ok, ecron:refresh()),
    timer:sleep(300),
    ?assertEqual(3, length(ecron:list())),
    JobKey = mnesia:dirty_first(?JOB_TABLE),
    ?assertMatch({Schedule3, _}, JobKey),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey3]},
			      {{Y,M,D}, Time3}},
                       schedule = {{'*', '*', '*'}, Time3},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey)),
    JobKey1 = mnesia:dirty_next(?JOB_TABLE, JobKey),
    ?assertMatch({Schedule2, _}, JobKey1),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey2]},
			      DateTime2},
                       schedule = DateTime2, client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey1)),
    JobKey2 = mnesia:dirty_next(?JOB_TABLE, JobKey1),
    ?assertMatch({Schedule1, _}, JobKey2),
    ?assertMatch([#job{mfa = {{ecron_tests, test_function, [UniqueKey1]},
			      {{Y,M,D}, Time}},
                       schedule = {{'*', '*', '*'}, Time},
		       client_fun = undefined}],
                 mnesia:dirty_read(?JOB_TABLE, JobKey2)),
    JobKey3 = mnesia:dirty_next(?JOB_TABLE, JobKey2),
    ?assertEqual('$end_of_table', JobKey3),
    ?assertEqual(ok, ecron:delete_all()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

execute_all() ->
    LT = ecron_time:localtime(),
    Schedule = calendar:datetime_to_gregorian_seconds(LT)+30,
    DateTime = calendar:gregorian_seconds_to_datetime(Schedule),
    {A,B,C} = now(),
    UniqueKey = lists:concat([A, "-", B, "-", C]),
    ?assertEqual(ok, ecron:insert(
		       DateTime,
		       {ecron_tests, test_not_ok_function, [UniqueKey]})),

    Schedule1 = calendar:datetime_to_gregorian_seconds(LT)+60,
    {{_Y,_M,_D}, Time} = calendar:gregorian_seconds_to_datetime(Schedule1),
    {A1,B1,C1} = now(),
    UniqueKey1 = lists:concat([A1, "-", B1, "-", C1]),
    ?assertEqual(ok, ecron:insert(
		       {{'*', '*', '*'}, Time},
		       {ecron_tests, ok_mfa, [UniqueKey1]})),

    Schedule2 = calendar:datetime_to_gregorian_seconds(LT)+20,
    DateTime2 = calendar:gregorian_seconds_to_datetime(Schedule2),
    {A2,B2,C2} = now(),
    UniqueKey2 = lists:concat([A2, "-", B2, "-", C2]),
    ?assertEqual(ok, ecron:insert(
		       DateTime2,{ecron_tests, ok_mfa1, [UniqueKey2]})),

    Schedule3 = calendar:datetime_to_gregorian_seconds(LT)+50,
    DateTime3 = calendar:gregorian_seconds_to_datetime(Schedule3),
    {A3,B3,C3} = now(),
    UniqueKey3 = lists:concat([A3, "-", B3, "-", C3]),
    ?assertEqual(ok, ecron:insert(
		       DateTime3,{ecron_tests, retry_mfa, [UniqueKey3]}, 4, 1)),

    ?assertEqual(4, length(ecron:list())),
    ?assertEqual(ok, ecron:execute_all()),
    T = calendar:datetime_to_gregorian_seconds(ecron_time:localtime()),
    timer:sleep(300),
    ?assertEqual([{UniqueKey, T}], ets:lookup(ecron_test, UniqueKey)),
    ?assertEqual([{UniqueKey1, T}], ets:lookup(ecron_test, UniqueKey1)),
    ?assertEqual([{UniqueKey2, T}], ets:lookup(ecron_test, UniqueKey2)),
    ?assertEqual([{UniqueKey3, T}], ets:lookup(ecron_test, UniqueKey3)),

    ?assertEqual([], ecron:list()),
    ets:delete_all_objects(ecron_test),
    ets:delete_all_objects(event_test).

event_handler_api() ->
    EventHandlers = ecron:list_event_handlers(),
    ?assertMatch([{_, ecron_event_handler_test}], EventHandlers),
    ?assertEqual([ecron_event_handler_test], gen_event:which_handlers(?EVENT_MANAGER)),
    [{Pid, ecron_event_handler_test}] = EventHandlers,
    ?assertEqual(ok, ecron:delete_event_handler(Pid)),
    timer:sleep(100),
    ?assertEqual([], ecron:list_event_handlers()),
    ?assertEqual([], gen_event:which_handlers(?EVENT_MANAGER)),
    ?assertMatch({ok, _}, ecron:add_event_handler(ecron_event_handler_test, [])),
    ?assertMatch([{_, ecron_event_handler_test}], ecron:list_event_handlers()),
    ?assertEqual([ecron_event_handler_test], gen_event:which_handlers(?EVENT_MANAGER)).

test_function(Key) ->
    F = fun() ->
        ets:insert(ecron_test, {Key, test}),
        ok
    end,
    {apply, F}.

test_function1(Key) ->
    F = fun() ->
        ets:insert(ecron_test, {Key, test}),
        {ok, Key}
    end,
    {apply, F}.


test_not_ok_function(Key) ->
    Time = calendar:datetime_to_gregorian_seconds(ecron_time:localtime()),
    F = fun() ->
        ets:insert(ecron_test, {Key, Time}),
        {error, retry}
    end,
    {apply, F}.

wrong_fun(Key) ->
    Time = calendar:datetime_to_gregorian_seconds(ecron_time:localtime()),
    F = fun() ->
        ets:insert(ecron_test, {Key, Time}),
        wrong
    end,
    {apply, F}.

ok_mfa(Key) ->
    Time = calendar:datetime_to_gregorian_seconds(ecron_time:localtime()),
    ets:insert(ecron_test, {Key, Time}),
    ok.

ok_mfa1(Key) ->
    Time = calendar:datetime_to_gregorian_seconds(ecron_time:localtime()),
    ets:insert(ecron_test, {Key, Time}),
    {ok, Key}.

retry_mfa(Key) ->
    Time = calendar:datetime_to_gregorian_seconds(ecron_time:localtime()),
    ets:insert(ecron_test, {Key, Time}),
    {error, retry}.


wrong_mfa(Key) ->
    ets:insert(ecron_test, {Key, test}),
    wrong.


add_month({Y, M, D}) ->
    case M of
        12 -> {Y+1, 1, D};
        M  -> {Y, M+1, D}
    end.
