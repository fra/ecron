

<h1>The ecron application</h1>

The ecron application
=====================
The Ecron application.

__Authors:__ Francesca Gangemi ([`francesca@erlang-solutions.com`](mailto:francesca@erlang-solutions.com)), Ulf Wiger ([`ulf.wiger@erlang-solutions.com`](mailto:ulf.wiger@erlang-solutions.com)).

The Ecron application



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

<pre>
Copyright (c) 2009-2011  Erlang Solutions Ltd
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of the Erlang Solutions nor the names of its
  contributors may be used to endorse or promote products
  derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
BE  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>


<h2 class="indextitle">Modules</h2>



<table width="100%" border="0" summary="list of modules">
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron.md" class="module">ecron</a></td></tr>
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron_app.md" class="module">ecron_app</a></td></tr>
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron_event.md" class="module">ecron_event</a></td></tr>
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron_event_handler_controller.md" class="module">ecron_event_handler_controller</a></td></tr>
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron_event_sup.md" class="module">ecron_event_sup</a></td></tr>
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron_sup.md" class="module">ecron_sup</a></td></tr>
<tr><td><a href="http://github.com/esl/ecron/blob/master/doc/ecron_time.md" class="module">ecron_time</a></td></tr></table>

