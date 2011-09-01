Module ecron_event_sup
======================


<h1>Module ecron_event_sup</h1>

* [Function Index](#index)
* [Function Details](#functions)






__Behaviours:__ [`supervisor`](supervisor.md).

__Authors:__ Francesca Gangemi ([`francesca.gangemi@erlang-solutions.com`](mailto:francesca.gangemi@erlang-solutions.com)).

<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#init-1">init/1</a></td><td>Whenever a supervisor is started using supervisor:start_link/2,3,
this function is called by the new process to find out about restart strategy,
maximum restart frequency and child specifications.</td></tr><tr><td valign="top"><a href="#list_handlers-0">list_handlers/0</a></td><td>Returns a list of all event handlers installed by the
<code>start_handler/2</code> API.</td></tr><tr><td valign="top"><a href="#start_handler-2">start_handler/2</a></td><td>Starts a child that will add a new event handler.</td></tr><tr><td valign="top"><a href="#start_link-0">start_link/0</a></td><td>Starts the supervisor.</td></tr><tr><td valign="top"><a href="#stop_handler-1">stop_handler/1</a></td><td>Stop the child with the given Pid.</td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="init-1"></a>

<h3>init/1</h3>





<pre>init(Args) -> {ok, {SupFlags, [ChildSpec]}} | ignore</pre>
<br></br>




Whenever a supervisor is started using supervisor:start_link/2,3,
this function is called by the new process to find out about restart strategy,
maximum restart frequency and child specifications.<a name="list_handlers-0"></a>

<h3>list_handlers/0</h3>





<pre>list_handlers() -> [{Pid, Handler}]</pre>
<ul class="definitions"><li><pre>Handler = Module | {Module, Id}</pre></li><li><pre>Module = atom()</pre></li><li><pre>Id = term()</pre></li><li><pre>Pid = pid()</pre></li></ul>



Returns a list of all event handlers installed by the
`start_handler/2` API<a name="start_handler-2"></a>

<h3>start_handler/2</h3>





<pre>start_handler(Handler, Args) -> {ok, Pid} | {error, Error}</pre>
<br></br>




Starts a child that will add a new event handler<a name="start_link-0"></a>

<h3>start_link/0</h3>





<pre>start_link() -> {ok, Pid} | ignore | {error, Error}</pre>
<br></br>




Starts the supervisor<a name="stop_handler-1"></a>

<h3>stop_handler/1</h3>





<pre>stop_handler(Pid) -> ok</pre>
<br></br>




Stop the child with the given Pid. It will terminate the associated
event handler