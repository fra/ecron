Module ecron
============


<h1>Module ecron</h1>

* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


The Ecron API module.



__Behaviours:__ [`gen_server`](gen_server.md).

__Authors:__ Francesca Gangemi ([`francesca.gangemi@erlang-solutions.com`](mailto:francesca.gangemi@erlang-solutions.com)).

<h2><a name="description">Description</a></h2>





The Ecron application executes scheduled functions.
A list of functions to execute might be specified in the ecron application
resource file as value of the `scheduled` environment variable.

Each entry specifies a job and must contain the scheduled time and a MFA
tuple `{Module, Function, Arguments}`.
It's also possible to configure options for a retry algorithm to run in case
MFA fails.
<pre>
  Job =  {{Date, Time}, MFA, Retry, Seconds} |
         {{Date, Time}, MFA}
  </pre>


`Seconds = integer()` is the retry interval.



`Retry = integer() | infinity` is the number of times to retry.


Example of ecron.app
<pre>
  ...
  {env,[{scheduled,
         [{{{ '*', '*', '*'}, {0 ,0,0}}, {my_mod, my_fun1, Args}},
          {{{ '*', 12 ,  25}, {0 ,0,0}}, {my_mod, my_fun2, Args}},
          {{{ '*', 1  ,  1 }, {0 ,0,0}}, {my_mod, my_fun3, Args}, infinity, 60},
          {{{2010, 1  ,  1 }, {12,0,0}}, {my_mod, my_fun3, Args}},
          {{{ '*', 12 ,last}, {0 ,0,0}}, {my_mod, my_fun4, Args}]}]},
  ...
  </pre>


Once the ecron application is started, it's possible to dynamically add new
jobs using the `ecron:insert/2` or  `ecron:insert/4`  
API.



The MFA is executed when a task is set to run.
The MFA has to return `ok`, `{ok, Data}`, `{apply, fun()}`
or `{error, Reason}`.
If `{error, Reason}` is returned and the job was defined with retry options  
(Retry and Seconds were specified together with the MFA) then ecron will try  
to execute MFA later according to the given configuration.



The MFA may return `{apply, fun()}` where `fun()` has arity zero.



`fun` will be immediately executed after MFA execution.
The `fun` has to return `ok`, `{ok, Data}` or `{error, Reason}`.



If the MFA or `fun` terminates abnormally or returns an invalid
data type (not `ok`, `{ok, Data}` or `{error, Reason}`), an event  
is forwarded to the event manager and no retries are executed.



If the return value of the fun is `{error, Reason}` and retry
options were given in the job specification then the `fun` is  
rescheduled to be executed after the configurable amount of time.



Data which does not change between retries of the `fun`
must be calculated outside the scope of the `fun`.
Data which changes between retries has to be calculated within the scope
of the `fun`.
<br></br>
  
In the following example, ScheduleTime will change each time the function is  
scheduled, while ExecutionTime will change for every retry. If static data  
has to persist across calls or retries, this is done through a function in  
the MFA or the fun.

<pre>
  print() ->
    ScheduledTime = time(),
    {apply, fun() ->
        ExecutionTime = time(),
        io:format("Scheduled:~p~n",[ScheduledTime]),
        io:format("Execution:~p~n",[ExecutionTime]),
        {error, retry}
    end}.
  </pre>

  
Event handlers may be configured in the application resource file specifying  
for each of them, a tuple as the following:

<pre>{Handler, Args}
 
  Handler = Module | {Module,Id}
  Module = atom()
  Id = term()
  Args = term()
  </pre>
`Module:init/1` will be called to initiate the event handler and
its internal state
<br></br>

<br></br>

Example of ecron.app
<pre>
  ...
  {env, [{event_handlers, [{ecron_event, []}]}]},
  ...
  </pre>


The API `add_event_handler/2` and
`delete_event_handler/1`  
allow user to dynamically add and remove event handlers.



All the configured event handlers will receive the following events:



`{mfa_result, Result, {Schedule, {M, F, A}}, DueDateTime, ExecutionDateTime}`   
when MFA is  executed.



`{fun_result, Result, {Schedule, {M, F, A}}, DueDateTime, ExecutionDateTime}`
when `fun` is executed.



`{retry, {Schedule, MFA}, Fun, DueDateTime}`
when MFA, or `fun`, is rescheduled to be executed later after a failure.



`{max_retry, {Schedule, MFA}, Fun, DueDateTime}` when MFA,
or `fun` has reached maximum number of retry specified when  
the job was inserted.



`Result` is the return value of MFA or `fun`.
If an exception occurs during evaluation of MFA, or `fun`, then
it's caught and sent in the event.
(E.g. `Result = {'EXIT',{Reason,Stack}}`).

`Schedule = {Date, Time}` as given when the job was inserted, E.g.
`{{'*','*','*'}, {0,0,0}}`
<br></br>

`DueDateTime = {Date, Time}` is the exact Date and Time when the MFA,
or the `fun`, was supposed to run.
E.g. `{{2010,1,1}, {0,0,0}}`
<br></br>

`ExecutionDateTime = {Date, Time}` is the exact Date and Time
when the MFA, or the `fun`, was executed.
<br></br>

<br></br>

<br></br>

If a node is restarted while there are jobs in the list then these jobs are
not lost. When Ecron starts it takes a list of scheduled MFA from the
environment variable `scheduled` and inserts them into a persistent table
(mnesia). If an entry of the scheduled MFA specifies the same parameters
values of a job already present in the table then the entry won't be inserted
avoiding duplicated jobs. 
<br></br>

No duplicated are removed from the MFA list configured in the `scheduled` variable.


<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#add_event_handler-2">add_event_handler/2</a></td><td>Adds a new event handler.</td></tr><tr><td valign="top"><a href="#delete-1">delete/1</a></td><td>Deletes a cron job from the list.</td></tr><tr><td valign="top"><a href="#delete_all-0">delete_all/0</a></td><td>Delete all the scheduled jobs.</td></tr><tr><td valign="top"><a href="#delete_event_handler-1">delete_event_handler/1</a></td><td>Deletes an event handler.</td></tr><tr><td valign="top"><a href="#execute_all-0">execute_all/0</a></td><td>Executes all cron jobs in the queue, irrespective of the time they are
scheduled to run.</td></tr><tr><td valign="top"><a href="#insert-2">insert/2</a></td><td>Schedules the MFA at the given Date and Time.</td></tr><tr><td valign="top"><a href="#insert-4">insert/4</a></td><td>Schedules the MFA at the given Date and Time and retry if it fails.</td></tr><tr><td valign="top"><a href="#install-0">install/0</a></td><td>Create mnesia tables on those nodes where disc_copies resides according
to the schema.</td></tr><tr><td valign="top"><a href="#install-1">install/1</a></td><td>Create mnesia tables on Nodes.</td></tr><tr><td valign="top"><a href="#list-0">list/0</a></td><td>Returns a list of job records defined in ecron.hrl.</td></tr><tr><td valign="top"><a href="#list_event_handlers-0">list_event_handlers/0</a></td><td>Returns a list of all event handlers installed by the
<code>ecron:add_event_handler/2</code> API or configured in the
<code>event_handlers</code> environment variable.</td></tr><tr><td valign="top"><a href="#print_list-0">print_list/0</a></td><td>Prints a pretty list of records sorted by Job ID.</td></tr><tr><td valign="top"><a href="#refresh-0">refresh/0</a></td><td>Deletes all jobs and recreates the table from the environment variables.</td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="add_event_handler-2"></a>

<h3>add_event_handler/2</h3>





<pre>add_event_handler(Handler, Args) -> {ok, Pid} | {error, Reason}</pre>
<ul class="definitions"><li><pre>Handler = Module | {Module, Id}</pre></li><li><pre>Module = atom()</pre></li><li><pre>Id = term()</pre></li><li><pre>Args = term()</pre></li><li><pre>Pid = pid()</pre></li></ul>



Adds a new event handler. The handler is added regardless of whether
it's already present, thus duplicated handlers may exist.<a name="delete-1"></a>

<h3>delete/1</h3>





<pre>delete(ID) -> ok</pre>
<br></br>




Deletes a cron job from the list.
If the job does not exist, the function still returns ok

__See also:__ [print_list/0](#print_list-0).<a name="delete_all-0"></a>

<h3>delete_all/0</h3>





<pre>delete_all() -> ok</pre>
<br></br>




Delete all the scheduled jobs<a name="delete_event_handler-1"></a>

<h3>delete_event_handler/1</h3>





<pre>delete_event_handler(Pid) -> ok</pre>
<ul class="definitions"><li><pre>Pid = pid()</pre></li></ul>



Deletes an event handler. Pid is the pid() returned by
`add_event_handler/2`.<a name="execute_all-0"></a>

<h3>execute_all/0</h3>





<pre>execute_all() -> ok</pre>
<br></br>




Executes all cron jobs in the queue, irrespective of the time they are
scheduled to run. This might be used at startup and shutdown, ensuring no
data is lost and backedup data is handled correctly. 
<br></br>

It asynchronously returns `ok` and then executes all the jobs
in parallel. 
<br></br>

No retry will be executed even if the MFA, or the `fun`, fails
mechanism is enabled for that job. Also in case of periodic jobs MFA won't
be rescheduled. Thus the jobs list will always be empty after calling
`execute_all/0`.<a name="insert-2"></a>

<h3>insert/2</h3>





<pre>insert(DateTime, MFA) -> ok</pre>
<ul class="definitions"><li><pre>DateTime = {Date, Time}</pre></li><li><pre>Date = {Year, Month, Day} | '*'</pre></li><li><pre>Time = {Hours, Minutes, Seconds}</pre></li><li><pre>Year = integer() | '*'</pre></li><li><pre>Month = integer() | '*'</pre></li><li><pre>Day = integer() | '*' | last</pre></li><li><pre>Hours = integer()</pre></li><li><pre>Minutes = integer()</pre></li><li><pre>Seconds = integer()</pre></li><li><pre>MFA = {Module, Function, Args}</pre></li></ul>



Schedules the MFA at the given Date and Time. 
<br></br>

Inserts the MFA into the queue to be scheduled at
{Year,Month, Day},{Hours, Minutes,Seconds}
<br></br>

<pre>
  Month = 1..12 | '*'
  Day = 1..31 | '*' | last
  Hours = 0..23
  Minutes = 0..59
  Seconds = 0..59
  </pre>


If `Day = last` then the MFA will be executed last day of the month.



`{'*', Time}` runs the MFA every day at the given time and it's
the same as writing `{{'*','*','*'}, Time}`.



`{{'*', '*', Day}, Time}` runs the MFA every month at the given
Day and Time. It must be `Day = 1..28 | last`



`{{'*', Month, Day}, Time}` runs the MFA every year at the given
Month, Day and Time. Day must be valid for the given month or the atom
`last`.
If `Month = 2` then it must be `Day = 1..28 | last`



Combinations of the format `{'*', Month, '*'}` are not allowed.



`{{Year, Month, Day}, Time}` runs the MFA at the given Date and Time.

Returns `{error, Reason}` if invalid parameters have been passed.<a name="insert-4"></a>

<h3>insert/4</h3>





<pre>insert(DateTime, MFA, Retry, Seconds::RetrySeconds) -> ok</pre>
<ul class="definitions"><li><pre>DateTime = {Date, Time}</pre></li><li><pre>Date = {Year, Month, Day} | '*'</pre></li><li><pre>Time = {Hours, Minutes, Seconds}</pre></li><li><pre>Year = integer() | '*'</pre></li><li><pre>Month = integer() | '*'</pre></li><li><pre>Day = integer() | '*' | last</pre></li><li><pre>Hours = integer()</pre></li><li><pre>Minutes = integer()</pre></li><li><pre>Seconds = integer()</pre></li><li><pre>Retry = integer() | infinity</pre></li><li><pre>RetrySeconds = integer()</pre></li><li><pre>MFA = {Module, Function, Args}</pre></li></ul>





Schedules the MFA at the given Date and Time and retry if it fails.

Same description of insert/2. Additionally if MFA returns
`{error, Reason}`  ecron will retry to execute
it after `RetrySeconds`. The MFA will be rescheduled for a
maximum of Retry times. If MFA returns `{apply, fun()}` and the
return value of `fun()` is `{error, Reason}` the
retry mechanism applies to `fun`. If Retry is equal to 3
then MFA will be executed for a maximum of four times. The first time
when is supposed to run according to the schedule and then three more
times at interval of RetrySeconds.<a name="install-0"></a>

<h3>install/0</h3>





<pre>install() -> ok</pre>
<br></br>




Create mnesia tables on those nodes where disc_copies resides according
to the schema. 
<br></br>

Before starting the `ecron` application
for the first time a new database must be created, `mnesia:create_schema/1` and tables created by `ecron:install/0` or
`ecron:install/1`
<br></br>

E.g. 
<br></br>

<pre>
  >mnesia:create_schema([node()]).
  >mnesia:start().
  >ecron:install().
  </pre><a name="install-1"></a>

<h3>install/1</h3>





<pre>install(Nodes) -> ok</pre>
<br></br>




Create mnesia tables on Nodes.<a name="list-0"></a>

<h3>list/0</h3>





<pre>list() -> JobList</pre>
<br></br>




Returns a list of job records defined in ecron.hrl<a name="list_event_handlers-0"></a>

<h3>list_event_handlers/0</h3>





<pre>list_event_handlers() -> [{Pid, Handler}]</pre>
<ul class="definitions"><li><pre>Handler = Module | {Module, Id}</pre></li><li><pre>Module = atom()</pre></li><li><pre>Id = term()</pre></li><li><pre>Pid = pid()</pre></li></ul>



Returns a list of all event handlers installed by the
`ecron:add_event_handler/2` API or configured in the
`event_handlers` environment variable.<a name="print_list-0"></a>

<h3>print_list/0</h3>





<pre>print_list() -> ok</pre>
<br></br>




Prints a pretty list of records sorted by Job ID. 
<br></br>

E.g. 
<br></br>

<pre>
  -----------------------------------------------------------------------
  ID: 208
  Function To Execute: mfa
  Next Execution DateTime: {{2009,11,8},{15,59,54}}
  Scheduled Execution DateTime: {{2009,11,8},{15,59,34}}
  MFA: {ecron_tests,test_function,[fra]}
  Schedule: {{'*','*',8},{15,59,34}}
  Max Retry Times: 4
  Retry Interval: 20
  -----------------------------------------------------------------------
  </pre>


__`ID`__ is the Job ID and should be used as argument in
`delete/1`.
<br></br>

__`Function To Execute`__ says if the job refers to the
MFA or the `fun` returned by MFA.



__`Next Execution DateTime`__ is the date and time when  
the job will be executed.



__`Scheduled Execution DateTime`__ is the date and time
when the job was supposed to be executed according to the given
`Schedule`.`Next Execution DateTime` and
`Scheduled Execution DateTime` are different if the MFA, or
the `fun`, failed and it will be retried later  
(as in the example given above).



__`MFA`__ is a tuple with Module, Function and Arguments as
given when the job was inserted.
<br></br>

__`Schedule`__ is the schedule for the MFA as given when the
job was insterted.
<br></br>

__`Max Retry Times`__ is the number of times ecron will retry to  
execute the job in case of failure. It may be less than the value given  
when the job was inserted if a failure and a retry has already occured.

__`Retry Interval`__ is the number of seconds ecron will wait
after a failure before retrying to execute the job. It's the value given
when the job was inserted.<a name="refresh-0"></a>

<h3>refresh/0</h3>





<pre>refresh() -> ok</pre>
<br></br>




Deletes all jobs and recreates the table from the environment variables.