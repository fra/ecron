Module ecron_sup
================


<h1>Module ecron_sup</h1>

* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


Supervisor module.



__Authors:__ Francesca Gangemi ([`francesca.gangemi@erlang-solutions.com`](mailto:francesca.gangemi@erlang-solutions.com)).

<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#init-1">init/1</a></td><td>Whenever a supervisor is started using supervisor:start_link/2,3,
this function is called by the new process to find out about restart strategy,
maximum restart frequency and child specifications.</td></tr><tr><td valign="top"><a href="#start_link-0">start_link/0</a></td><td>Starts the supervisor.</td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="init-1"></a>

<h3>init/1</h3>





<pre>init(Args) -> {ok, {SupFlags, [ChildSpec]}} | ignore</pre>
<br></br>




Whenever a supervisor is started using supervisor:start_link/2,3,
this function is called by the new process to find out about restart strategy,
maximum restart frequency and child specifications.<a name="start_link-0"></a>

<h3>start_link/0</h3>





<pre>start_link() -> {ok, Pid} | ignore | {error, Error}</pre>
<br></br>




Starts the supervisor